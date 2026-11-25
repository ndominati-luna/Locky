import Foundation
import LockyKit
import Observation
import OSLog
import UIKit

/// Root model of the iPhone app: glues the Bluetooth session, the sensors, the preferences, iCloud,
/// widgets, the Apple Watch and notifications together.
@MainActor
@Observable
final class AppModel {
    let preferences: Preferences
    let session: PhoneSession
    let intrusions: IntrusionStore

    private(set) var macStatus: MacStatus?
    private(set) var visuals: MacVisuals
    private(set) var proximity: ProximityReading? {
        didSet { updateLiveActivity() }
    }
    private(set) var isMoving: Bool = false
    /// The password was sent: the Mac is typing it (drives the dots of the lock screen imitation).
    private(set) var isUnlocking: Bool = false {
        didSet { updateLiveActivity() }
    }
    /// Transient message displayed to the user (errors, refused commands).
    var alertMessage: String?
    /// Navigation from the main screen (its toolbar buttons, intrusion notifications).
    var path: [AppRoute] = []
    /// The About sheet, opened from the toolbar of the main screen.
    var isAboutPresented: Bool = false
    /// The video of the first Locky, found in About (``LockyStoryView``). Presented from the main
    /// screen, not over About: a cover over a sheet closes when an iPhone Duo unfolds.
    var isStoryPresented: Bool = false
    /// Lock animation of the Mac, sent by Locky for Mac 1.0.2 and later.
    private(set) var macLockAnimation: LockAnimationSettings? {
        didSet { preferences.macLockAnimation = macLockAnimation }
    }
    /// Versions of Locky for Mac, newest first; `nil` until read from the Sparkle feed.
    private(set) var macReleases: [MacRelease]?
    /// Guided first try after the pairing; `nil` once done or skipped.
    private(set) var setup: SetupPhase? {
        didSet { applyTouchIDDefaultIfNeeded() }
    }
    /// Live state of the Mac, streamed while the dashboard is on screen (unfolded iPhone Duo).
    private(set) var macMetrics: MacMetrics?
    /// What the Mac is playing; `nil` when nothing.
    private(set) var nowPlaying: NowPlaying?
    /// Artwork of ``nowPlaying``, fetched from iCloud.
    private(set) var nowPlayingArtwork: Data?
    /// Calibration of the distance asked from the settings.
    private(set) var distanceCalibration: DistanceCalibration = .ready(.near)

    @ObservationIgnored private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "AppModel")
    @ObservationIgnored private let motion: MotionMonitor = .init()
    @ObservationIgnored private let calls: CallMonitor = .init()
    @ObservationIgnored private let battery: BatteryMonitor = .init()
    @ObservationIgnored private let notifications: NotificationManager = .init()
    @ObservationIgnored private let sounds: SoundPlayer = .init()
    @ObservationIgnored private let watch: WatchBridge = .init()
    @ObservationIgnored private let widgets: WidgetBridge = .init()
    @ObservationIgnored private let liveActivity: LiveActivityManager = .init()
    @ObservationIgnored private let passwords: PasswordVault = .init()
    @ObservationIgnored private var isStarted: Bool = false
    @ObservationIgnored private var lastPedometerRefresh: ContinuousClock.Instant?
    @ObservationIgnored private var unlockingTimeout: Task<Void, Never>?
    @ObservationIgnored private var isDashboardVisible: Bool = false
    /// Last artwork fetched, kept for the next tracks with the same one.
    @ObservationIgnored private var lastArtwork: (id: String, data: Data)?
    /// Revision of ``nowPlaying`` in iCloud (Mac on Locky 1.0.0).
    @ObservationIgnored private var nowPlayingRevision: String?
    @ObservationIgnored private var nowPlayingFetch: Task<Void, Never>?
    /// Artwork being fetched from iCloud.
    @ObservationIgnored private var fetchingArtworkID: String?
    /// Last change of the lock animation made here: the echo of the Mac is ignored meanwhile, so
    /// that a text being typed is not set back to its previous letters.
    @ObservationIgnored private var lockAnimationEditedAt: ContinuousClock.Instant?
    @ObservationIgnored private var calibrationTimeout: Task<Void, Never>?
    /// The settings of the Mac changed out of reach, on their way to iCloud.
    @ObservationIgnored private var macSettingsUpload: Task<Void, Never>?

    init() {
        preferences = .init()
        session = .init()
        intrusions = .init()
        macStatus = MacStatusCache.load()
        macLockAnimation = preferences.macLockAnimation
        visuals = .stored()
        motion.baseline = preferences.motionBaseline
        wireCallbacks()
    }

    // MARK: - Lifecycle

    /// Starts every service. Safe to call several times.
    /// - Parameter inBackground: iOS launched Locky in background (Bluetooth, iCloud, widget). If the
    ///   user had closed it from the app switcher, Bluetooth stays silent until Locky is opened.
    func start(inBackground: Bool = false) {
        guard !isStarted else { return }
        isStarted = true
        isDormant = inBackground && UserDefaults.standard.bool(forKey: Self.closedByUserKey)
        LockyCommandRouter.handler = { [weak self] command, origin in
            await self?.perform(command, origin: origin) ?? false
        }
        #if DEBUG
        if DemoMode.isEnabled {
            startDemo()
            return
        }
        #endif
        notifications.configure()
        widgets.start()
        watch.start()
        battery.start()
        if preferences.onboardingCompleted {
            session.start(dormant: isDormant)
        }
        // The motion of the iPhone is followed once the Mac is connected (``sessionOpened()``).
        // Images stored by an earlier version: the copies the extensions display are missing.
        if visuals.needsRenditions {
            visuals.storeRenditions(frame: macFrame)
            widgets.reloadAll()
        }
        publishState()
        Task { await refreshFromCloud() }
    }

    // MARK: - Closing from the app switcher

    private static let closedByUserKey: String = "locky.closedByUser"

    /// Locky was closed by the user and relaunched in background by iOS: Bluetooth is silent.
    @ObservationIgnored private var isDormant: Bool = false

    /// The user closes Locky from the app switcher (iOS calls this when Locky was still running in
    /// background): the Live Activity goes away and the Mac can no longer reach the iPhone, until
    /// Locky is opened again.
    func prepareForTermination() {
        UserDefaults.standard.set(true, forKey: Self.closedByUserKey)
        liveActivity.endBeforeTermination()
        session.withdraw()
    }

    /// Opened (or asked for a command from a widget, a shortcut, the Watch): Locky works again.
    private func wakeIfDormant() {
        UserDefaults.standard.removeObject(forKey: Self.closedByUserKey)
        guard isDormant else { return }
        isDormant = false
        if preferences.onboardingCompleted {
            session.start()
        }
    }

    /// Called at the end of the onboarding: triggers the Bluetooth, notification and Motion &
    /// Fitness prompts, the three it announces.
    func completeOnboarding() async {
        preferences.onboardingCompleted = true
        session.start()
        await notifications.requestAuthorization()
        await motion.requestAuthorization()
    }

    func sceneBecameActive() {
        isOnScreen = true
        updateProximityInterest()
        wakeIfDormant()
        notifications.clearBadge()
        widgets.drainCommands()
        startLiveActivityIfNeeded()
        Task { await refreshFromCloud() }
    }

    /// Locky left the screen: the Mac stops sending the distance nothing shows.
    func sceneEnteredBackground() {
        isOnScreen = false
        updateProximityInterest()
    }

    // MARK: - Distance from the Mac

    /// Locky is on screen (between becoming active and going to the background).
    @ObservationIgnored private var isOnScreen: Bool = false
    /// What the Mac was last told, `nil` since the session opened.
    @ObservationIgnored private var sentProximityInterest: ProximityInterest?

    /// Tells the Mac how often the distance is shown: live on screen, every few seconds in the
    /// Live Activity, never otherwise; each reading it sends wakes the iPhone.
    private func updateProximityInterest() {
        #if DEBUG
        if DemoMode.isEnabled {
            return
        }
        #endif
        guard isConnected, macStatus?.supports(.proximityOnDemand) == true else { return }
        let interest: ProximityInterest = if isOnScreen {
            .live
        } else if preferences.liveActivityEnabled, liveActivity.isRunning {
            .glance
        } else {
            .none
        }
        // Remembered only once sent: an interest lost on the way would leave the Mac silent, and
        // the gauge on a distance of the past.
        guard interest != sentProximityInterest, session.send(.proximityInterest(interest)) else { return }
        sentProximityInterest = interest
    }

    // MARK: - Live Activity

    /// Live Activities are allowed for Locky in the Settings app.
    var areLiveActivitiesAllowed: Bool {
        liveActivity.isAllowed
    }

    /// The Live Activity setting changed (from the foreground: the activity can start).
    func liveActivitySettingDidChange() {
        if preferences.liveActivityEnabled {
            startLiveActivityIfNeeded()
        } else {
            liveActivity.end()
        }
        updateProximityInterest()
    }

    /// Starts (or takes over) the Live Activity. iOS only allows it from the foreground.
    private func startLiveActivityIfNeeded() {
        guard preferences.liveActivityEnabled, session.isPaired, setup == nil else { return }
        liveActivity.start(
            attributes: .init(macName: macName, family: macStatus?.family ?? .unknown),
            state: liveActivityState
        )
    }

    private func updateLiveActivity() {
        guard preferences.liveActivityEnabled, session.isPaired else { return }
        // Not running yet (just paired, ended by iOS after 8 hours): start it while in the foreground.
        if !liveActivity.isRunning, UIApplication.shared.applicationState == .active {
            startLiveActivityIfNeeded()
        } else {
            liveActivity.update(liveActivityState)
        }
    }

    private var liveActivityState: LockyActivityAttributes.ContentState {
        .init(
            lockState: lockState,
            lockStateDate: macStatus?.lockStateDate,
            isConnected: isConnected,
            distance: isConnected ? proximity?.distance : nil,
            lockDistance: preferences.lockDistance,
            isAutoLockEnabled: macStatus?.isAutoLockEnabled ?? true,
            isUnlocking: isUnlocking,
            unlockOnlyFromWatch: preferences.unlockOnlyFromWatch,
            imagesVersion: preferences.macImagesVersion
        )
    }

    // MARK: - State

    var lockState: LockState {
        macStatus?.lockState ?? .unknown
    }

    var isConnected: Bool {
        session.connection.isConnected
    }

    var macName: String {
        macStatus?.name ?? session.pairing?.peerName ?? "Mac"
    }

    /// Distance model built from the pairing calibration.
    var distanceModel: DistanceModel? {
        session.pairing?.distanceModel
    }

    var snapshot: LockySnapshot {
        .init(
            isPaired: session.isPaired,
            macName: session.isPaired ? macName : nil,
            family: macStatus?.family ?? .unknown,
            isConnected: isConnected,
            lockState: lockState,
            lockStateDate: macStatus?.lockStateDate,
            isAutoLockEnabled: macStatus?.isAutoLockEnabled ?? true,
            unlockOnlyFromWatch: preferences.unlockOnlyFromWatch,
            lockDistance: preferences.lockDistance,
            updatedAt: .now
        )
    }

    // MARK: - Camera of the Mac

    /// Intruder detection is on but the Mac cannot photograph intruders: why (refused, never asked,
    /// no camera). `nil` when everything is fine or the Mac did not say.
    var missingMacCameraAccess: CameraAccess? {
        guard preferences.intrusionDetection, let access = macStatus?.cameraAccess, !access.canTakePhotos else { return nil }
        return access
    }

    /// Asks the Mac to let Locky use its camera: macOS asks, or System Settings opens on Camera.
    func allowMacCamera() {
        #if DEBUG
        if DemoMode.isEnabled {
            Task {
                try? await Task.sleep(for: .seconds(2))
                macStatus?.cameraAccess = .authorized
            }
            return
        }
        #endif
        session.send(.cameraAccessRequest)
    }

    // MARK: - Commands

    /// Executes a command coming from the app, a widget, a control, Siri or the Watch.
    func perform(_ command: LockyCommand, origin: CommandOrigin) async -> Bool {
        #if DEBUG
        if DemoMode.isEnabled {
            await simulateDemoCommand(command)
            return true
        }
        #endif
        // A widget, a shortcut or the Watch asks for Locky again after it was closed.
        wakeIfDormant()
        switch command {
        case .lock:
            return lock(origin: origin)
        case .unlock:
            return await unlock(origin: origin)
        case .toggle:
            return lockState == .locked ? await unlock(origin: origin) : lock(origin: origin)
        }
    }

    @discardableResult
    func lock(origin: CommandOrigin) -> Bool {
        guard isConnected else {
            alertMessage = String(localized: "Your Mac is not connected.")
            return false
        }
        return session.send(.lock(origin: origin))
    }

    @discardableResult
    func unlock(origin: CommandOrigin) async -> Bool {
        guard isConnected else {
            alertMessage = String(localized: "Your Mac is not connected.")
            return false
        }
        if preferences.unlockOnlyFromWatch, origin != .watch {
            alertMessage = String(localized: "Locky is set to unlock your Mac only from your Apple Watch.")
            return false
        }
        if preferences.requireBiometrics, origin == .app {
            guard await BiometricGate.authenticate(reason: String(localized: "Authenticate to unlock your Mac")) else {
                return false
            }
        }
        return sendPassword(origin: origin)
    }

    private func sendPassword(origin: CommandOrigin) -> Bool {
        guard let password = passwords.password() else {
            alertMessage = String(localized: "Locky does not know your Mac password yet. Use \"Update session password\" in the Locky menu on your Mac.")
            return false
        }
        let sent: Bool = session.send(.unlock(password: password, origin: origin))
        if sent {
            beginUnlocking()
        }
        return sent
    }

    private func beginUnlocking() {
        isUnlocking = true
        unlockingTimeout?.cancel()
        unlockingTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            self?.isUnlocking = false
        }
    }

    private func handlePasswordRequest(_ reason: PasswordRequestReason) async {
        guard !preferences.unlockOnlyFromWatch else { return }
        switch reason {
        case .proximity:
            guard preferences.unlockAutomatically else { return }
            _ = sendPassword(origin: .proximity)
        case .lockScreenButton:
            guard preferences.requireBiometrics else {
                _ = sendPassword(origin: .lockScreen)
                return
            }
            if UIApplication.shared.applicationState == .active {
                if await BiometricGate.authenticate(reason: String(localized: "Authenticate to unlock your Mac")) {
                    _ = sendPassword(origin: .lockScreen)
                }
            } else {
                notifications.post(
                    identifier: "unlock-request",
                    body: String(localized: "Tap to unlock your Mac with \(BiometricGate.biometryName)."),
                    category: NotificationManager.Category.unlockRequest,
                    interruption: .timeSensitive
                )
            }
        }
    }

    /// The user opened the notification asking to authenticate (Unlock pressed on the lock screen
    /// of the Mac): once the app is in front, Face ID or Touch ID, without a second prompt when it
    /// just unlocked the iPhone, then the password goes to the Mac.
    private func unlockFromOpenedRequest() async {
        var attempts: Int = 0
        while UIApplication.shared.applicationState != .active, attempts < 30 {
            try? await Task.sleep(for: .milliseconds(100))
            attempts += 1
        }
        let reason: String = .init(localized: "Authenticate to unlock your Mac")
        guard await BiometricGate.authenticate(reason: reason, reusingRecentUnlock: true) else { return }
        _ = sendPassword(origin: .notification)
    }

    // MARK: - Preferences

    /// The iPhone lies at the distance of the current step (1 m, then 2 m) and the user confirmed:
    /// the Mac measures the signal there.
    func calibrateDistance() {
        let step: CalibrationStep
        switch distanceCalibration {
        case let .ready(next): step = next
        case .failed: step = .near
        case .measuring, .done: return
        }
        calibrationTimeout?.cancel()
        #if DEBUG
        if DemoMode.isEnabled {
            distanceCalibration = .measuring(step)
            calibrationTimeout = Task {
                try? await Task.sleep(for: CalibrationStep.measureDuration)
                calibrationMeasured(step)
            }
            return
        }
        #endif
        guard session.requestCalibration(step) else {
            distanceCalibration = .failed
            return
        }
        distanceCalibration = .measuring(step)
        calibrationTimeout = Task {
            try? await Task.sleep(for: CalibrationStep.measureDuration + .seconds(6))
            guard !Task.isCancelled, distanceCalibration == .measuring(step) else { return }
            distanceCalibration = .failed
        }
    }

    /// Back to the first step (the calibration screen closed).
    func resetDistanceCalibration() {
        guard !distanceCalibration.isMeasuring else { return }
        calibrationTimeout?.cancel()
        distanceCalibration = .ready(.near)
    }

    private func calibrationMeasured(_ step: CalibrationStep) {
        calibrationTimeout?.cancel()
        distanceCalibration = step == .near ? .ready(.far) : .done
    }

    /// Sends the preferences to the Mac after a change.
    func preferencesDidChange() {
        let current: PhonePreferences = preferences.phonePreferences
        macSettingDidChange(.preferences(current)) { $0.preferences = .init(current, date: $1) }
        publishState()
    }

    /// The settings of the Mac can be changed here: in reach, or out of reach with a Mac that reads
    /// them in iCloud.
    var canChangeMacSettings: Bool {
        isConnected || macStatus?.supports(.cloudSettings) == true
    }

    /// Records a change of a setting of the Mac with its date, then delivers it: over Bluetooth in
    /// reach, otherwise through iCloud to a Mac that reads it there (an older one gets the
    /// preferences when it comes back in reach).
    private func macSettingDidChange(_ message: LockyMessage, record: (inout MacSettingsEnvelope, Date) -> Void) {
        record(&preferences.macSettings, .now)
        #if DEBUG
        if DemoMode.isEnabled {
            return
        }
        #endif
        guard !session.send(message), macStatus?.supports(.cloudSettings) == true else { return }
        preferences.isMacSettingsUploadPending = true
        macSettingsUpload?.cancel()
        // A moment after the last change: a text being typed goes once.
        macSettingsUpload = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            await self?.uploadMacSettings()
        }
    }

    /// Leaves the settings of the Mac changed out of reach in iCloud, sealed with the pairing key.
    /// Kept pending when it fails: tried again at the next iCloud refresh.
    private func uploadMacSettings() async {
        guard preferences.isMacSettingsUploadPending, let pairing = session.pairing, let key = session.pairingKey else { return }
        let envelope: MacSettingsEnvelope = preferences.macSettings
        do {
            let sealed: Data = try envelope.sealed(key: key, macID: pairing.peerID)
            try await CloudSync.shared.publishMacSettings(sealed, macID: pairing.peerID)
            // A change made meanwhile goes with the next upload.
            if preferences.macSettings == envelope {
                preferences.isMacSettingsUploadPending = false
            }
            logger.notice("Settings of the Mac left in iCloud")
        } catch {
            logger.notice("Settings of the Mac not left in iCloud: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Forgets the Mac.
    func unpair() {
        session.unpair(notifyMac: isConnected)
        passwords.clear()
        preferences.resetPairingRelatedValues()
        macStatus = nil
        MacStatusCache.save(nil)
        visuals = .init()
        visuals.store()
        proximity = nil
        setup = nil
        macMetrics = nil
        nowPlaying = nil
        nowPlayingArtwork = nil
        intrusions.clear()
        motion.stop()
        SharedStore.reset()
        liveActivity.end()
        publishState()
    }

    // MARK: - iCloud

    /// Fetches the Mac record and the intrusion reports from iCloud.
    func refreshFromCloud() async {
        #if DEBUG
        guard !DemoMode.isEnabled else { return }
        #endif
        guard let pairing = session.pairing else { return }
        logger.notice("iCloud refresh (known images \(self.preferences.macImagesVersion ?? "none", privacy: .public))")
        do {
            if let record = try await CloudSync.shared.fetchMac(macID: pairing.peerID, knownImagesVersion: preferences.macImagesVersion) {
                apply(cloudRecord: record)
            }
        } catch {
            logger.notice("iCloud fetch of the Mac failed: \(error.localizedDescription, privacy: .public)")
        }
        await intrusions.refresh(macID: pairing.peerID)
        await uploadMacSettings()
        // The silent push brings the new wallpaper of the Mac even without intrusion detection.
        try? await CloudSync.shared.registerSubscriptions(
            intrusionAlertKey: preferences.intrusionDetection ? "Someone just tried to unlock your Mac!" : nil
        )
    }

    private func apply(cloudRecord: CloudMacRecord) {
        var cloudStatus: MacStatus = cloudRecord.status
        if !isConnected, cloudStatus.lockStateDate > (macStatus?.lockStateDate ?? .distantPast) {
            // iCloud does not keep the version of Locky for Mac nor its features (Bluetooth only).
            cloudStatus.appVersion = macStatus?.appVersion
            cloudStatus.appBuild = macStatus?.appBuild
            cloudStatus.features = macStatus?.features
            cloudStatus.hasTouchID = macStatus?.hasTouchID
            cloudStatus.showsUnlockButton = macStatus?.showsUnlockButton
            // Changed here out of reach after the Mac published: the Mac has not read it yet.
            if let autoLock = preferences.macSettings.autoLock, autoLock.date > cloudRecord.modifiedAt ?? .distantPast {
                cloudStatus.isAutoLockEnabled = autoLock.value
            }
            updateStatus(cloudStatus)
        }
        logger.notice("""
            iCloud record of the Mac: images \(cloudRecord.imagesVersion ?? "none", privacy: .public) \
            (known \(self.preferences.macImagesVersion ?? "none", privacy: .public)), \
            wallpaper \(cloudRecord.wallpaper?.count ?? 0) B, complete \(cloudRecord.isComplete)
            """)
        // The images only come through iCloud: their version tells whether they changed.
        guard let imagesVersion = cloudRecord.imagesVersion, imagesVersion != preferences.macImagesVersion else { return }
        // iCloud downloads the images to protected files, unreadable while the iPhone is locked: an
        // incomplete record keeps the current images, fetched again later (at the latest when
        // Locky is opened) rather than storing empty ones.
        guard cloudRecord.isComplete else {
            logger.notice("Images of the Mac incomplete (iPhone locked?), fetched again later")
            return
        }
        visuals = .init(
            wallpaper: cloudRecord.wallpaper,
            userPicture: cloudRecord.userPicture,
            phone: cloudRecord.phoneImage ?? visuals.phone
        )
        visuals.store()
        visuals.storeRenditions(frame: macFrame)
        preferences.macImagesVersion = imagesVersion
        logger.notice("Images of the Mac stored (\(imagesVersion, privacy: .public))")
        // The widgets show the wallpaper but their snapshot did not change: reload them explicitly.
        widgets.reloadAll()
        publishState()
    }

    /// The Mac has just uploaded new images: fetch them now rather than waiting for the silent push.
    /// Also runs in the background, the Bluetooth link keeps the app awake.
    private func fetchMacImages(version: String) {
        guard version != preferences.macImagesVersion, let pairing = session.pairing else { return }
        let start: ContinuousClock.Instant = .now
        Task {
            do {
                // The Mac announced them: status and images in a single request.
                guard let record = try await CloudSync.shared.fetchMac(
                    macID: pairing.peerID,
                    knownImagesVersion: preferences.macImagesVersion,
                    imagesAreNew: true
                ) else { return }
                logger.notice("Mac images \(version, privacy: .public) fetched in \(ContinuousClock.now - start, privacy: .public)")
                apply(cloudRecord: record)
            } catch {
                logger.notice("iCloud fetch of the Mac images failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    #if DEBUG
    /// Fills the model with sample data (launch argument `-LockyDemo`).
    private func startDemo() {
        preferences.onboardingCompleted = true
        if let step = DemoMode.pairingStep {
            session.injectDemoPairingStep(step)
            return
        }
        let macID: UUID = .init()
        session.injectDemoPairing(.init(
            pairingID: .init(),
            peerID: macID,
            peerName: "MacBook Pro",
            calibrationRSSI: -65,
            pairedAt: .now
        ))
        macStatus = DemoMode.macStatus(macID: macID)
        macLockAnimation = DemoMode.lockAnimation
        visuals = DemoMode.visuals
        // Widgets and the Live Activity read the images from the App Group.
        visuals.store()
        visuals.storeRenditions(frame: macFrame)
        proximity = .init(rssi: -58, distance: 1.3)
        isMoving = false
        intrusions.injectDemoReports(DemoMode.intrusions(macID: macID))
        path = DemoMode.initialPath
        startDashboardDemo()
        publishState()
        if let demoSetup = DemoMode.setup {
            startSetupDemo(demoSetup)
            return
        }
        if UserDefaults.standard.bool(forKey: "LockyDemoAutoUnlock") {
            Task {
                try? await Task.sleep(for: .seconds(2))
                await simulateDemoCommand(.unlock)
                try? await Task.sleep(for: .seconds(2))
                await simulateDemoCommand(.lock)
            }
        }
        if UserDefaults.standard.bool(forKey: "LockyDemoWalk") {
            Task { await playDemoWalk() }
        }
    }

    /// The walk of `-LockyDemoWalk` on the main screen, for demo films: the iPhone walks away until
    /// the Mac locks, waits, then comes back until it unlocks, with the thresholds of
    /// ``ProximityEngine`` (the lock distance, then 70 % of it).
    private func playDemoWalk() async {
        let lockDistance: Double = preferences.lockDistance
        let near: Double = 0.6
        let far: Double = lockDistance + 1.5
        let step: Double = 0.1
        let pace: Duration = .seconds(0.18)
        proximity = .init(rssi: -55, distance: near)
        try? await Task.sleep(for: .seconds(2.5))
        isMoving = true
        for distance in stride(from: near, through: far, by: step) {
            proximity = .init(rssi: -60, distance: distance)
            if distance >= lockDistance, lockState != .locked {
                await simulateDemoCommand(.lock)
            }
            try? await Task.sleep(for: pace)
        }
        isMoving = false
        try? await Task.sleep(for: .seconds(3))
        isMoving = true
        for distance in stride(from: far, through: near, by: -step) {
            proximity = .init(rssi: -60, distance: distance)
            if distance <= lockDistance * ProximityEngine.unlockDistanceRatio, lockState == .locked, !isUnlocking {
                Task { await simulateDemoCommand(.unlock) }
            }
            try? await Task.sleep(for: pace)
        }
        isMoving = false
    }

    /// Guided first try demo (`-LockyDemoSetup waiting|walkAway|comeBack|magic|tour`). The tour
    /// plays the whole try: the iPhone walks away, the Mac locks, the iPhone comes back, it unlocks.
    private func startSetupDemo(_ demo: DemoMode.SetupDemo) {
        switch demo {
        case let .phase(phase):
            setup = phase
            if phase == .comeBack, var status = macStatus {
                status.lockState = .locked
                updateStatus(status)
            }
            proximity = .init(rssi: -60, distance: phase == .comeBack ? 4.2 : 1.1)
        case .tour:
            Task {
                setup = .waitingForMac
                try? await Task.sleep(for: .seconds(3))
                macSentSetupProgress(.firstTry)
                let lockDistance: Double = preferences.lockDistance
                for distance in stride(from: 0.4, through: lockDistance + 1.4, by: 0.45) {
                    proximity = .init(rssi: -60, distance: distance)
                    isMoving = true
                    try? await Task.sleep(for: .seconds(0.8))
                }
                await simulateDemoCommand(.lock)
                advanceSetup(for: .locked)
                try? await Task.sleep(for: .seconds(2))
                for distance in stride(from: lockDistance + 1.4, through: lockDistance * 0.6, by: -0.45) {
                    proximity = .init(rssi: -60, distance: distance)
                    try? await Task.sleep(for: .seconds(0.8))
                }
                isMoving = false
                beginUnlocking()
                try? await Task.sleep(for: .seconds(0.9))
                macSentSetupProgress(.succeeded)
                await simulateDemoCommand(.unlock)
            }
        }
    }

    /// Demo dashboard: a busy Mac playing music.
    private func startDashboardDemo() {
        macMetrics = DemoMode.metrics(cpuUsage: 0.24)
        updateNowPlaying(DemoMode.track(0, isPlaying: true))
        Task {
            var load: Double = 0.24
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                load = min(0.92, max(0.06, load + Double.random(in: -0.12...0.12)))
                let volume: Double? = macMetrics?.outputVolume
                let isMuted: Bool = macMetrics?.isMuted ?? false
                macMetrics = DemoMode.metrics(cpuUsage: load)
                macMetrics?.outputVolume = volume
                macMetrics?.isMuted = isMuted
            }
        }
    }

    private func simulateDemoMediaCommand(_ command: MediaCommand) {
        guard let playing = nowPlaying, let index = DemoMode.trackIndex(of: playing) else { return }
        switch command {
        case .nextTrack:
            updateNowPlaying(DemoMode.track(index + 1, isPlaying: true))
        case .previousTrack:
            updateNowPlaying(DemoMode.track(index - 1, isPlaying: true))
        default:
            break
        }
    }

    /// Demo mode: behaves like a Mac answering the commands.
    private func simulateDemoCommand(_ command: LockyCommand) async {
        guard var status = macStatus else { return }
        let lock: Bool = switch command {
        case .lock: true
        case .unlock: false
        case .toggle: status.lockState != .locked
        }
        if !lock {
            beginUnlocking()
            try? await Task.sleep(for: .seconds(0.9))
        }
        status.lockState = lock ? .locked : .unlocked
        status.lockStateDate = .now
        isUnlocking = false
        updateStatus(status)
    }
    #endif

    // MARK: - Private

    private func wireCallbacks() {
        session.onSessionOpened = { [weak self] in self?.sessionOpened() }
        session.onSessionClosed = { [weak self] in self?.sessionClosed() }
        session.onMessage = { [weak self] message in self?.handle(message) }
        session.onPasswordReceived = { [weak self] password in self?.passwords.save(password) ?? false }
        session.onCalibrationRequested = { [weak self] _ in self?.calibrate() }
        session.onHeartbeat = { [weak self] in self?.heartbeat() }
        session.onCalibrationMeasured = { [weak self] step in self?.calibrationMeasured(step) }
        motion.onChange = { [weak self] moving in
            self?.isMoving = moving
            self?.session.send(.motion(isMoving: moving))
        }
        calls.onChange = { [weak self] onCall in self?.session.send(.call(isActive: onCall)) }
        battery.onChange = { [weak self] level in self?.session.send(.battery(level: level)) }
        notifications.onUnlockAction = { [weak self] in
            guard let self else { return }
            _ = self.sendPassword(origin: .notification)
        }
        notifications.onUnlockRequestOpened = { [weak self] in
            Task { await self?.unlockFromOpenedRequest() }
        }
        notifications.onIntrusionOpened = { [weak self] in self?.path = [.intrusions] }
        widgets.onCommand = { [weak self] pending in
            Task { await self?.perform(pending.command, origin: pending.origin) }
        }
        watch.onCommand = { [weak self] command in
            await self?.perform(command, origin: .watch) ?? false
        }
    }

    private func sessionOpened() {
        motion.start()
        let status: DeviceStatus = .init(
            name: LocalDevice.name,
            model: LocalDevice.model,
            modelIdentifier: LocalDevice.modelIdentifier,
            systemVersion: LocalDevice.systemVersion,
            appVersion: LocalDevice.appVersion,
            batteryLevel: battery.level,
            preferences: preferences.phonePreferences,
            macImagesVersion: preferences.macImagesVersion,
            features: LockyFeature.current
        )
        session.send(.deviceStatus(status))
        // Settings changed out of reach: the Mac may not have read them in iCloud. It keeps those
        // chosen after its own.
        if macStatus?.supports(.cloudSettings) == true, !preferences.macSettings.isEmpty,
           session.send(.macSettings(preferences.macSettings)) {
            preferences.isMacSettingsUploadPending = false
            macSettingsUpload?.cancel()
        }
        session.send(.motion(isMoving: motion.isMoving))
        session.send(.call(isActive: calls.isOnCall))
        if isDashboardVisible {
            session.send(.dashboard(isVisible: true))
        }
        publishState()
    }

    private func sessionClosed() {
        proximity = nil
        macMetrics = nil
        sentProximityInterest = nil
        // Out of reach, the Mac does not need to know whether the iPhone moves; the pedometer
        // tells it once Locky wakes up again (``heartbeat()``).
        motion.stop()
        // Only true while the Mac is there (it forgets it in iCloud when Locky quits).
        nowPlayingFetch?.cancel()
        fetchingArtworkID = nil
        nowPlaying = nil
        nowPlayingArtwork = nil
        nowPlayingRevision = nil
        publishState()
    }

    private func heartbeat() {
        if let lastPedometerRefresh, ContinuousClock.now - lastPedometerRefresh < .seconds(2) { return }
        lastPedometerRefresh = .now
        motion.refreshFromPedometer()
        widgets.drainCommands()
    }

    private func calibrate() {
        Task {
            let baseline: MotionBaseline = await motion.calibrate()
            preferences.motionBaseline = baseline
            motion.baseline = baseline
            session.completePairing(preferences: preferences.phonePreferences)
            // A new pairing: automatic unlocking turns off after the first try if the Mac has Touch ID.
            preferences.isTouchIDDefaultPending = session.isPaired
            if session.isPaired {
                // The guided first try continues on the Mac (permissions, then "Try it now").
                setup = .waitingForMac
            }
            motion.start()
            await notifications.requestAuthorization()
            publishState()
        }
    }

    private func handle(_ message: LockyMessage) {
        switch message {
        case let .macStatus(status):
            updateStatus(status)
            // Its features are known: it can be told how often to send the distance.
            updateProximityInterest()
        case let .macImagesUpdated(version):
            fetchMacImages(version: version)
        case let .lockState(state):
            lockStateChanged(state)
        case let .autoLock(isEnabled):
            guard var status = macStatus else { return }
            status.isAutoLockEnabled = isEnabled
            updateStatus(status)
        case let .unlockButton(isShown):
            guard var status = macStatus else { return }
            status.showsUnlockButton = isShown
            updateStatus(status)
        case let .proximity(reading):
            proximity = reading
        case let .passwordRequest(reason):
            Task { await handlePasswordRequest(reason) }
        case .unlockFailed:
            let message: String = .init(localized: "Your Mac refused the password. If you changed it, choose \"Update session password\" in the Locky menu on your Mac.")
            alertMessage = message
            notifications.post(identifier: "unlock-failed", body: message)
        case .unpair:
            unpair()
        case let .setupProgress(progress):
            macSentSetupProgress(progress)
        case let .macMetrics(metrics):
            macMetrics = metrics
        case let .nowPlayingChanged(revision):
            fetchNowPlaying(revision: revision)
        case let .nowPlaying(playing):
            receiveNowPlaying(playing)
        case let .lockAnimation(settings):
            // The echo of a change made here is skipped; a change made on the Mac shows up.
            if let lockAnimationEditedAt, ContinuousClock.now - lockAnimationEditedAt < .seconds(1.5) {
                return
            }
            macLockAnimation = settings
        default:
            break
        }
    }

    // MARK: - Dashboard

    /// The dashboard (second page of an unfolded iPhone Duo) appeared or disappeared: the Mac
    /// streams its state only while it is on screen.
    func setDashboardVisible(_ isVisible: Bool) {
        guard isVisible != isDashboardVisible else { return }
        isDashboardVisible = isVisible
        #if DEBUG
        if DemoMode.isEnabled {
            return
        }
        #endif
        session.send(.dashboard(isVisible: isVisible))
    }

    /// Playback and volume of the Mac. The dashboard reflects the command at once.
    /// Changes the lock animation of the Mac, which applies it at once.
    func setMacLockAnimation(_ settings: LockAnimationSettings) {
        guard settings != macLockAnimation else { return }
        macLockAnimation = settings
        lockAnimationEditedAt = .now
        guard macStatus?.supports(.lockAnimation) == true else { return }
        macSettingDidChange(.lockAnimation(settings)) { $0.lockAnimation = .init(settings, date: $1) }
    }

    /// Plays the lock animation on the Mac, without locking it.
    func previewMacLockAnimation() {
        guard macStatus?.supports(.lockAnimation) == true else { return }
        session.send(.previewLockAnimation)
    }

    /// Opens the update window of Sparkle on the Mac.
    func updateMac() {
        guard macStatus?.supports(.macUpdates) == true else { return }
        session.send(.checkForUpdates)
    }

    /// Reads the versions of Locky for Mac from the Sparkle feed; `false` when it failed.
    @discardableResult
    func loadMacReleases() async -> Bool {
        guard let releases = try? await MacReleaseFeed.fetch() else { return false }
        macReleases = releases
        return true
    }

    /// A version newer than the one on the Mac. A Mac that does not tell its version runs Locky
    /// 1.0.1 or earlier.
    var availableMacUpdate: MacRelease? {
        guard let latest = macReleases?.first, let status = macStatus else { return nil }
        return latest.build > (status.appBuild ?? 0) ? latest : nil
    }

    /// "Locky activated" on the Mac: automatic locking when the iPhone walks away. Shown at once;
    /// the Mac confirms with the same message.
    func setMacAutoLock(_ isEnabled: Bool) {
        guard var status = macStatus, status.isAutoLockEnabled != isEnabled else { return }
        status.isAutoLockEnabled = isEnabled
        updateStatus(status)
        macSettingDidChange(.autoLock(isEnabled: isEnabled)) { $0.autoLock = .init(isEnabled, date: $1) }
    }

    /// Shows or hides the Unlock button of the lock screen of a Mac that has the setting
    /// (``LockyFeature/unlockButton``); the wings stay.
    func setMacUnlockButton(_ isShown: Bool) {
        guard var status = macStatus, status.supports(.unlockButton), status.showsUnlockButton != isShown else { return }
        status.showsUnlockButton = isShown
        updateStatus(status)
        macSettingDidChange(.unlockButton(isShown: isShown)) { $0.unlockButton = .init(isShown, date: $1) }
    }

    /// After a new pairing, once the guided first try is over (or skipped) and the Mac has told
    /// whether it has Touch ID: with Touch ID the finger unlocks, automatic unlocking turns off (the
    /// Mac hides its Unlock button itself). A Mac too old to tell keeps it on.
    private func applyTouchIDDefaultIfNeeded() {
        guard preferences.isTouchIDDefaultPending, setup == nil || setup == .magic, let status = macStatus else { return }
        guard let hasTouchID = status.hasTouchID else {
            // An older Mac: it says nothing of Touch ID.
            if status.features != nil {
                preferences.isTouchIDDefaultPending = false
            }
            return
        }
        preferences.isTouchIDDefaultPending = false
        guard hasTouchID, preferences.unlockAutomatically else { return }
        logger.notice("Touch ID on the new Mac: automatic unlocking off")
        preferences.unlockAutomatically = false
        preferencesDidChange()
    }

    func sendMediaCommand(_ command: MediaCommand) {
        switch command {
        case .playPause:
            if var playing = nowPlaying {
                playing.elapsed = playing.elapsed(at: .now)
                playing.elapsedDate = .now
                playing.isPlaying.toggle()
                nowPlaying = playing
            }
        case let .seek(position):
            if var playing = nowPlaying {
                playing.elapsed = position
                playing.elapsedDate = .now
                nowPlaying = playing
            }
        case let .setVolume(volume):
            macMetrics?.outputVolume = volume
            if volume > 0 {
                macMetrics?.isMuted = false
            }
        case .toggleMute:
            macMetrics?.isMuted.toggle()
        case .nextTrack, .previousTrack:
            break
        }
        #if DEBUG
        if DemoMode.isEnabled {
            simulateDemoMediaCommand(command)
            return
        }
        #endif
        session.send(.mediaCommand(command))
    }

    private func updateNowPlaying(_ playing: NowPlaying?) {
        if let artwork = playing?.artwork, let artworkID = playing?.artworkID {
            lastArtwork = (artworkID, artwork)
        }
        // The next tracks of an album share the artwork, downloaded once.
        if let artworkID = playing?.artworkID, let lastArtwork, lastArtwork.id == artworkID {
            nowPlayingArtwork = lastArtwork.data
        } else {
            nowPlayingArtwork = nil
        }
        var stored: NowPlaying? = playing
        stored?.artwork = nil
        nowPlaying = stored
    }

    /// What the Mac is playing, straight over Bluetooth. A new artwork comes from iCloud, the
    /// next tracks of the album reuse it.
    private func receiveNowPlaying(_ playing: NowPlaying?) {
        updateNowPlaying(playing)
        guard
            let artworkID = playing?.artworkID,
            lastArtwork?.id != artworkID,
            artworkID != fetchingArtworkID,
            let pairing = session.pairing
        else { return }
        nowPlayingFetch?.cancel()
        fetchingArtworkID = artworkID
        nowPlayingFetch = Task {
            defer {
                if fetchingArtworkID == artworkID {
                    fetchingArtworkID = nil
                }
            }
            let image: Data?
            do {
                image = try await CloudSync.shared.fetchNowPlayingArtwork(macID: pairing.peerID, artworkID: artworkID)
            } catch {
                logger.notice("iCloud fetch of the artwork failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard !Task.isCancelled, let image else { return }
            lastArtwork = (artworkID, image)
            if nowPlaying?.artworkID == artworkID {
                nowPlayingArtwork = image
            }
        }
    }

    /// A Mac still on Locky 1.0.0 published what it plays: fetch it from iCloud, its artwork only
    /// when it is new.
    private func fetchNowPlaying(revision: String) {
        guard revision != nowPlayingRevision, let pairing = session.pairing else { return }
        nowPlayingFetch?.cancel()
        let knownArtworkID: String? = lastArtwork?.id
        nowPlayingFetch = Task {
            let fetched: CloudNowPlaying?
            do {
                fetched = try await CloudSync.shared.fetchNowPlaying(macID: pairing.peerID, knownArtworkID: knownArtworkID)
            } catch {
                logger.notice("iCloud fetch of what the Mac plays failed: \(error.localizedDescription, privacy: .public)")
                return
            }
            guard !Task.isCancelled else { return }
            guard let cloud = fetched else {
                logger.notice("Nothing playing in iCloud for revision \(revision, privacy: .public)")
                return
            }
            logger.notice("""
            Now playing \(cloud.revision, privacy: .public) fetched: \(cloud.playing == nil ? "nothing" : "a track", privacy: .public), \
            artwork \(cloud.artworkID ?? "none", privacy: .public)
            """)
            nowPlayingRevision = cloud.revision
            var playing: NowPlaying? = cloud.playing
            playing?.artwork = cloud.artwork
            updateNowPlaying(playing)
        }
    }

    // MARK: - Guided first try

    /// The user closed the celebration of the first try (mandatory, it cannot be skipped): back to
    /// the main screen.
    func finishSetup() {
        if setup != .magic {
            session.send(.setupProgress(.finished))
        }
        setup = nil
    }

    private func macSentSetupProgress(_ progress: SetupProgress) {
        switch progress {
        case .permissions:
            if setup != .magic {
                setup = .waitingForMac
            }
        case .firstTry:
            setup = lockState == .locked ? .comeBack : .walkAway
        case .succeeded:
            setup = .magic
        case .finished:
            // Leave the celebration on screen until the user closes it.
            if setup != .magic {
                setup = nil
            }
        }
    }

    private func advanceSetup(for state: LockState) {
        switch (setup, state) {
        case (.walkAway, .locked): setup = .comeBack
        // Unlocked by hand (Touch ID, password): the first try starts over.
        case (.comeBack, .unlocked): setup = .walkAway
        default: break
        }
    }

    private func updateStatus(_ status: MacStatus) {
        let isNewMac: Bool = status.deviceType != macStatus?.deviceType || status.model != macStatus?.model
        macStatus = status
        MacStatusCache.save(status)
        applyTouchIDDefaultIfNeeded()
        if isNewMac {
            // Another image of the catalog: the widgets and the Live Activity need theirs.
            visuals.storeRenditions(frame: macFrame)
            widgets.reloadAll()
        }
        publishState()
    }

    /// The paired Mac from the catalog embedded in the app, its screen transparent.
    var macFrame: MacFrame? {
        MacFrame.catalog(deviceType: macStatus?.deviceType, model: macStatus?.model)
    }

    private func lockStateChanged(_ state: LockState) {
        guard var status = macStatus else { return }
        let previous: LockState = status.lockState
        status.lockState = state
        status.lockStateDate = .now
        updateStatus(status)
        guard previous != state else { return }
        advanceSetup(for: state)
        let isForeground: Bool = UIApplication.shared.applicationState == .active
        switch state {
        case .locked:
            if isForeground {
                sounds.play(preferences.soundTheme)
            } else if preferences.notificationsEnabled {
                notifications.post(
                    identifier: "lock-state",
                    body: String(localized: "Your Mac is locked."),
                    sound: notifications.sound(for: preferences.soundTheme),
                    interruption: .passive
                )
            }
        case .unlocked:
            unlockingTimeout?.cancel()
            isUnlocking = false
            if !isForeground, preferences.notificationsEnabled {
                notifications.post(
                    identifier: "lock-state",
                    body: String(localized: "Your Mac is unlocked."),
                    sound: nil,
                    interruption: .passive
                )
            }
        case .unknown:
            break
        }
    }

    private func publishState() {
        let snapshot: LockySnapshot = snapshot
        widgets.publish(snapshot)
        watch.publish(snapshot, imagesVersion: preferences.macImagesVersion)
        updateLiveActivity()
    }
}
