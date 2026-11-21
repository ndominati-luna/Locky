import AppKit
import Foundation
import LockyKit
import Observation
import OSLog

/// Root model of the Mac app: proximity engine, session locking, lock screen overlay, intruder
/// detection, iCloud publication and menu bar state.
@MainActor
@Observable
final class MacAppModel {
    let preferences: MacPreferences = .init()
    let session: MacSession = .init()
    let updater: UpdaterController = .init()

    private(set) var isLocked: Bool = SessionLocker.isScreenLocked
    private(set) var proximity: ProximityReading?
    private(set) var isPhoneMoving: Bool = false
    private(set) var isPhoneOnCall: Bool = false
    private(set) var isAccessibilityGranted: Bool = AccessibilityPermission.isGranted
    /// Permission of Locky for the camera (photos of intruders), sent to the iPhone with the status.
    private(set) var cameraAccess: CameraAccess = IntruderCamera.access
    /// Access to a wallpaper kept in a protected folder (Documents…), asked with an explanation.
    private(set) var wallpaperAccess: WallpaperAccess.Status = WallpaperAccess.status
    private(set) var isLaunchAtLoginEnabled: Bool = LaunchAtLogin.isEnabled
    /// Step of the setup shown in the pairing window once paired.
    private(set) var setupStep: MacSetupStep = .permissions

    /// Brings the pairing window to the front (the first try succeeded behind the lock screen).
    @ObservationIgnored var onShowSetupWindow: (() -> Void)?
    /// Closes the pairing window (the setup was skipped on the iPhone).
    @ObservationIgnored var onCloseSetupWindow: (() -> Void)?

    @ObservationIgnored private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "MacAppModel")
    @ObservationIgnored private let transitions: TransitionController = .init()
    @ObservationIgnored private let notifier: MacNotifier = .init()
    @ObservationIgnored private let events: SystemEventsObserver = .init()
    @ObservationIgnored private let intrusions: IntrusionDetector = .init()
    @ObservationIgnored private let widgets: MacWidgetBridge = .init()
    @ObservationIgnored private let dashboard: DashboardStreamer = .init()
    @ObservationIgnored private var engine: ProximityEngine?
    @ObservationIgnored private var isSleeping: Bool = false
    @ObservationIgnored private var disconnectionTask: Task<Void, Never>?
    @ObservationIgnored private var unlockInProgress: Bool = false
    @ObservationIgnored private var unlockRequestedAt: ContinuousClock.Instant?
    @ObservationIgnored private var lastPasswordRequest: ContinuousClock.Instant?
    @ObservationIgnored private var lastProximitySent: ContinuousClock.Instant?
    @ObservationIgnored private var images: MacImages?
    /// Version of the images already in iCloud: the iPhone is only told about those.
    @ObservationIgnored private var cloudImagesVersion: String?
    /// Version the iPhone was told about during the current session.
    @ObservationIgnored private var announcedImagesVersion: String?
    @ObservationIgnored private var wallpaperSignature: String?
    @ObservationIgnored private let wallpaperWatcher: WallpaperWatcher = .init()
    @ObservationIgnored private var backgroundTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var lowBatteryWarned: Bool = false
    /// Proximity may unlock only after the iPhone has actually been away: a lock asked by the user
    /// while the iPhone sits next to the Mac must not be undone seconds later.
    @ObservationIgnored private var isProximityUnlockArmed: Bool = false
    /// The current approach of the iPhone was already handled (prompt shown or password asked).
    @ObservationIgnored private var hasHandledApproach: Bool = false
    /// The Mac refused the stored password: stop retrying automatically until a new one is stored.
    @ObservationIgnored private var isStoredPasswordRejected: Bool = false
    @ObservationIgnored private var sessionClosedAt: ContinuousClock.Instant?
    /// Prompt hidden with the lock screen interface (display asleep): shown again with it.
    @ObservationIgnored private var promptHiddenWithLockScreen: LockScreenPromptView.Mode?
    /// Locky is locking the Mac (animation playing, session not locked yet).
    @ObservationIgnored private var lockingSince: ContinuousClock.Instant?
    #if DEBUG
    /// Film of the lock screen demo (`-LockyDemoRecordLockScreen YES`).
    @ObservationIgnored private var lockScreenFilm: LockScreenFilm?
    #endif
    /// Setup progress not delivered yet: the session reopens right after the pairing.
    @ObservationIgnored private var pendingSetupProgress: SetupProgress?
    /// Intruder detection was turned on while the Mac was locked: macOS asks for the camera once
    /// it is unlocked (nobody could answer on the lock screen).
    @ObservationIgnored private var isCameraRequestPending: Bool = false
    /// Follows the camera permission while System Settings is open (macOS sends no event).
    @ObservationIgnored private var cameraWatch: Task<Void, Never>?

    /// Seconds without any input after which the Mac is considered unused.
    private static let inUseIdleThreshold: TimeInterval = 3

    // MARK: - Lifecycle

    func start() {
        notifier.configure()
        notifier.onOpenCameraSettings = { [weak self] in self?.allowCamera() }
        wireSession()
        wireEvents()
        intrusions.isOwnerNearby = { [weak self] in
            guard let self, self.session.connection.isConnected, let proximity = self.proximity else { return false }
            return proximity.distance <= self.preferences.phonePreferences.lockDistance
        }
        intrusions.onReport = { [weak self] photo in self?.reportIntrusion(photo: photo) }
        dashboard.send = { [weak self] message in self?.session.send(message) ?? false }
        // What was playing is only true while Locky runs: forget it at launch (Locky may have been
        // killed) before publishing anything new.
        let macID: UUID = session.macID
        let launchCleanup: Task<Void, Never> = Task { try? await CloudSync.shared.clearNowPlaying(macID: macID) }
        dashboard.publishNowPlaying = { [weak self] playing, revision in
            await launchCleanup.value
            guard let macID = self?.session.macID else { return false }
            do {
                try await CloudSync.shared.publishNowPlaying(macID: macID, playing: playing, revision: revision)
                return true
            } catch {
                self?.logger.notice("Now playing publication failed: \(String(describing: error), privacy: .public)")
                return false
            }
        }
        #if DEBUG
        if MacDemo.isDashboardLog {
            dashboard.startLogging()
        }
        if MacDemo.isLockScreenPrompt {
            Task {
                try? await Task.sleep(for: .seconds(1))
                transitions.showPrompt(deviceName: "iPhone", mode: .button) {}
                // Then leaves as on a login.
                try? await Task.sleep(for: .seconds(5))
                transitions.hidePrompt()
            }
        }
        if MacDemo.isLockScreenProbe {
            probeLockScreen()
        }
        if MacDemo.isLockScreenOverlay {
            demoLockScreenOverlay()
        }
        if MacDemo.isLockScreenFilm {
            recordLockScreenFilm()
            // No Bluetooth: the film needs neither the iPhone nor the pairing, and must not compete
            // with another Locky for the iPhone (it shares the pairing when signed by the team).
            return
        }
        if let step = MacDemo.setupStep {
            startSetupDemo(step)
            return
        }
        if MacDemo.isPairingTour {
            startPairingTour()
            return
        }
        if MacDemo.isEnabled {
            startDemo()
            return
        }
        #endif
        if isSetupPending {
            // Quit or killed during the mandatory first try: it goes on at the next connection.
            setupStep = .permissions
            pendingSetupProgress = .permissions
        }
        rebuildEngine()
        session.start()
        startBackgroundTasks()
        widgets.onCommand = { [weak self] command in self?.perform(command) }
        widgets.start()
        observeWidgetState()
        Task {
            await notifier.requestAuthorization()
            refreshImages(force: true)
        }
    }

    #if DEBUG
    /// Pairing window demo (launch argument `-LockyDemoPairingTour YES`): every step in a loop,
    /// setup included.
    private func startPairingTour() {
        Task {
            while !Task.isCancelled {
                for step in MacDemo.pairingTourSteps {
                    setupStep = .permissions
                    session.injectDemoPairingStep(step)
                    try? await Task.sleep(for: .seconds(4))
                }
                session.injectDemoPairingStep(.completed)
                setupStep = .firstTry
                for distance in [0.4, 1.1, 2.2, 3.4] {
                    proximity = .init(rssi: -60, distance: distance)
                    try? await Task.sleep(for: .seconds(1))
                }
                setupStep = .magic
                try? await Task.sleep(for: .seconds(4))
            }
        }
    }

    /// Setup demo (launch argument `-LockyDemoSetup permissions|firstTry|magic`): one setup step,
    /// with an iPhone walking back and forth during the first try.
    private func startSetupDemo(_ step: MacSetupStep) {
        session.injectDemoPairingStep(.completed)
        session.injectDemoPairing(
            .init(pairingID: .init(), peerID: .init(), peerName: "iPhone", calibrationRSSI: -65, pairedAt: .now),
            modelIdentifier: "iPhone18,1"
        )
        setupStep = step
        guard step == .firstTry else { return }
        Task {
            let distances: [Double] = [0.4, 0.9, 1.6, 2.4, 3.3, 2.4, 1.6, 0.9]
            while !Task.isCancelled {
                for distance in distances {
                    proximity = .init(rssi: -60, distance: distance)
                    try? await Task.sleep(for: .seconds(1.2))
                }
            }
        }
    }


    /// Calibration: the whole sequence on the real lock screen (lock animation, wings, button),
    /// photographed.
    private func demoLockScreenOverlay() {
        Task {
            try? await Task.sleep(for: .seconds(1))
            transitions.lock(animated: true, title: preferences.effectiveLockAnimationTitle) {
                SessionLocker.lock()
            }
            // Is the animation still above the lock screen after the lock?
            try? await Task.sleep(for: .seconds(TransitionController.lockDuration + 0.25))
            Self.capture(to: "/tmp/locky-after-lock-1.png")
            try? await Task.sleep(for: .seconds(0.75))
            Self.capture(to: "/tmp/locky-after-lock-2.png")
            try? await Task.sleep(for: .seconds(1.2))
            SessionLocker.wakeDisplay()
            try? await Task.sleep(for: .seconds(1))
            transitions.showPrompt(deviceName: phoneName, mode: .button) {}
            try? await Task.sleep(for: .seconds(2.5))
            let anchors: String = LockScreenLayout.anchors().description
            try? anchors.write(to: URL(filePath: "/tmp/locky-lockscreen-anchors.txt"), atomically: true, encoding: .utf8)
            Self.capture(to: "/tmp/locky-lockscreen-overlay.png")
            // Do the wings follow the picture when macOS asks for the password (key pressed)?
            for index in 1...12 where SessionLocker.isScreenLocked {
                try? await Task.sleep(for: .seconds(1.5))
                Self.capture(to: "/tmp/locky-lockscreen-follow-\(index).png")
            }
        }
    }

    /// Films the whole show (`-LockyDemoRecordLockScreen YES`): the locking animation, the wings on
    /// the real lock screen, then, after a click on their Unlock button, the cover shown while Locky
    /// types the password. Unlock with Touch ID or the Apple Watch while it is shown.
    private func recordLockScreenFilm() {
        // Screen Recording for the film, Accessibility for the wings: asked before locking, as the
        // lock screen would hide the prompts of macOS.
        let canFilm: Bool = CGPreflightScreenCaptureAccess()
        guard canFilm, AccessibilityPermission.isGranted else {
            if !canFilm {
                _ = CGRequestScreenCaptureAccess()
            }
            if !AccessibilityPermission.isGranted {
                AccessibilityPermission.request()
            }
            notifier.post(
                identifier: MacNotifier.Identifier.status,
                title: "Lock screen film",
                body: "Allow Locky to record the screen and to use Accessibility, then launch the demo again."
            )
            return
        }
        let film: LockScreenFilm = .init()
        lockScreenFilm = film
        film.start()
        Task {
            // screencapture takes a moment to start filming.
            try? await Task.sleep(for: .seconds(2))
            transitions.lock(animated: true, title: preferences.effectiveLockAnimationTitle) {
                SessionLocker.lock()
            }
            try? await Task.sleep(for: .seconds(TransitionController.lockDuration + 2))
            SessionLocker.wakeDisplay()
            try? await Task.sleep(for: .seconds(1))
            showFilmPrompt()
        }
    }

    /// The wings with their Unlock button; clicked, they wait for the iPhone a moment, then the
    /// unlock cover appears as when the password arrives.
    private func showFilmPrompt() {
        transitions.showPrompt(deviceName: phoneName, mode: .button) { [weak self] in
            guard let self else { return }
            self.transitions.showPrompt(deviceName: self.phoneName, mode: .waitingForPhone) {}
            Task {
                try? await Task.sleep(for: .seconds(1.2))
                self.transitions.beginUnlock(animated: true, title: self.preferences.effectiveLockAnimationTitle)
            }
        }
    }

    private static func capture(to path: String) {
        let capture: Process = .init()
        capture.executableURL = URL(filePath: "/usr/sbin/screencapture")
        capture.arguments = ["-x", "-D", "1", path]
        try? capture.run()
    }

    /// Calibration: locks, waits for the lock screen, then dumps its elements.
    private func probeLockScreen() {
        Task {
            try? await Task.sleep(for: .seconds(1))
            SessionLocker.lock()
            try? await Task.sleep(for: .seconds(3))
            SessionLocker.wakeDisplay()
            try? await Task.sleep(for: .seconds(2))
            let report: String = """
            macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
            screens: \(NSScreen.screens.map { NSStringFromRect($0.frame) })
            locked: \(SessionLocker.isScreenLocked)
            \(LockScreenLayout.anchors())

            \(LockScreenLayout.dump())
            """
            try? report.write(to: URL(filePath: "/tmp/locky-lockscreen.txt"), atomically: true, encoding: .utf8)
        }
    }

    /// Demo mode (launch argument `-LockyDemo YES`): a paired, connected iPhone without Bluetooth,
    /// to review the menu and the widget. "Lock now" really locks the Mac.
    private func startDemo() {
        session.injectDemoPairing(
            .init(pairingID: .init(), peerID: .init(), peerName: "iPhone", calibrationRSSI: -65, pairedAt: .now),
            modelIdentifier: "iPhone18,1"
        )
        preferences.device = .init(
            name: "iPhone",
            model: "iPhone",
            modelIdentifier: "iPhone18,1",
            systemVersion: "27.2",
            appVersion: "3.0 (1)",
            batteryLevel: 78,
            preferences: preferences.phonePreferences,
            macImagesVersion: nil
        )
        proximity = .init(rssi: -58, distance: 1.3)
        startBackgroundTasks()
        widgets.onCommand = { [weak self] command in self?.perform(command) }
        widgets.start()
        observeWidgetState()
        if MacDemo.isLockAnimation {
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                previewLockAnimation()
            }
        }
    }
    #endif

    // MARK: - State

    var isPaired: Bool {
        session.isPaired
    }

    var phoneName: String {
        preferences.device?.name ?? session.pairing?.peerName ?? String(localized: "iPhone")
    }

    var phoneImage: NSImage? {
        let identifier: String? = preferences.device?.modelIdentifier ?? session.peerModelIdentifier
        return identifier.flatMap(DeviceIcon.image(forModelIdentifier:))
    }

    var batteryLevel: Int? {
        preferences.device?.batteryLevel
    }

    var macStatus: MacStatus {
        .init(
            macID: session.macID,
            name: MacDeviceInfo.name,
            model: MacDeviceInfo.modelIdentifier,
            productName: MacDeviceInfo.productName,
            family: MacDeviceInfo.family,
            systemVersion: MacDeviceInfo.systemVersion,
            userName: MacDeviceInfo.userName,
            lockState: isLocked ? .locked : .unlocked,
            lockStateDate: .now,
            isAutoLockEnabled: preferences.isAutoLockEnabled,
            unlockCount: preferences.unlockCount,
            cameraAccess: cameraAccess,
            deviceType: DeviceIcon.thisMacType
        )
    }

    // MARK: - User actions

    /// Locky quits: what is playing is no longer followed, forget it in iCloud (3 seconds at most).
    func prepareForTermination() async {
        dashboard.stop()
        let macID: UUID = session.macID
        let clearing: Task<Void, Never> = Task { try? await CloudSync.shared.clearNowPlaying(macID: macID) }
        let timeout: Task<Void, Never> = Task {
            try? await Task.sleep(for: .seconds(3))
            clearing.cancel()
        }
        await clearing.value
        timeout.cancel()
    }

    func setAutoLockEnabled(_ enabled: Bool) {
        preferences.isAutoLockEnabled = enabled
        session.send(.autoLock(isEnabled: enabled))
        publishToCloud()
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LaunchAtLogin.setEnabled(enabled)
        isLaunchAtLoginEnabled = LaunchAtLogin.isEnabled
    }

    func setLockAnimationEnabled(_ enabled: Bool) {
        preferences.isLockAnimationEnabled = enabled
        if enabled {
            transitions.prepareWallpaper()
        }
    }

    /// Plays the lock and unlock animations without locking the Mac.
    func previewLockAnimation() {
        transitions.playPreview(title: preferences.effectiveLockAnimationTitle)
    }

    func lockNow() {
        lockMac(fromProximity: false)
    }

    func requestAccessibility() {
        AccessibilityPermission.request()
    }

    /// The wallpaper is in a protected folder: macOS asks for it now that Locky explained why
    /// (System Settings after a refusal). Granted, the images are rendered with it at once.
    func requestWallpaperAccess() {
        Task {
            wallpaperAccess = await WallpaperAccess.request()
            refreshImages(force: true)
        }
    }

    /// The wallpaper may have moved, or the access been changed in System Settings.
    private func refreshWallpaperAccess() {
        let status: WallpaperAccess.Status = WallpaperAccess.status
        guard status != wallpaperAccess else { return }
        wallpaperAccess = status
        refreshImages(force: true)
    }

    /// Sends a new session password to the iPhone (after a password change).
    func updatePassword(_ password: String) async -> Bool {
        guard await PasswordVerifier.verify(password) else { return false }
        let sent: Bool = session.send(.storePassword(password))
        if sent {
            isStoredPasswordRejected = false
        }
        return sent
    }

    func unpair() {
        session.unpair(notifyPhone: session.connection.isConnected)
        resetAfterUnpairing()
    }

    func startPairing() {
        session.startPairing()
    }

    // MARK: - Setup

    /// The guided first try is mandatory after a pairing: the setup window stays open until it
    /// succeeded (pairings made before it was mandatory are done).
    var isSetupPending: Bool {
        isPaired && preferences.isSetupCompleted == false
    }

    /// Starts the guided first try, on the Mac and on the iPhone.
    func startFirstTry() {
        guard isAccessibilityGranted else {
            requestAccessibility()
            return
        }
        if !preferences.isAutoLockEnabled {
            setAutoLockEnabled(true)
        }
        setupStep = .firstTry
        sendSetupProgress(.firstTry)
    }

    /// Ends the setup once the first try succeeded and closes the window.
    func finishSetup() {
        onCloseSetupWindow?()
    }

    /// The pairing window closed: the setup is over on both devices.
    func setupWindowDidClose() {
        guard isPaired, session.pairingStep == .idle || session.pairingStep == .completed else { return }
        setupStep = .permissions
        sendSetupProgress(.finished)
    }

    private func sendSetupProgress(_ progress: SetupProgress) {
        pendingSetupProgress = session.send(.setupProgress(progress)) ? nil : progress
    }

    private func phoneSentSetupProgress(_ progress: SetupProgress) {
        // Skipped on the iPhone during the first try: nothing left to show on the Mac.
        guard progress == .finished, setupStep == .firstTry else { return }
        onCloseSetupWindow?()
    }

    // MARK: - Widget and controls

    /// What the desktop widget and the controls display.
    var widgetState: MacWidgetState {
        .init(
            isPaired: isPaired,
            phoneName: isPaired ? phoneName : nil,
            isConnected: session.connection.isConnected,
            distance: proximity.map { ($0.distance * 2).rounded() / 2 },
            lockDistance: preferences.phonePreferences.lockDistance,
            batteryLevel: batteryLevel,
            isAutoLockEnabled: preferences.isAutoLockEnabled,
            updatedAt: .now
        )
    }

    /// Publishes the widget state now and every time one of the values it reads changes.
    private func observeWidgetState() {
        let state: MacWidgetState = withObservationTracking {
            widgetState
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeWidgetState() }
        }
        widgets.publish(state, phoneModelIdentifier: preferences.device?.modelIdentifier ?? session.peerModelIdentifier)
    }

    /// Runs a command from the widget, a control, Shortcuts or Spotlight.
    func perform(_ command: MacCommand) {
        switch command {
        case .lockNow: lockNow()
        case .enableAutoLock: setAutoLockEnabled(true)
        case .disableAutoLock: setAutoLockEnabled(false)
        }
    }

    // MARK: - Session wiring

    private func wireSession() {
        session.onSessionOpened = { [weak self] in self?.sessionOpened() }
        session.onSessionClosed = { [weak self] in self?.sessionClosed() }
        session.onRSSI = { [weak self] rssi in self?.received(rssi: rssi) }
        session.onMessage = { [weak self] message in self?.handle(message) }
        session.onCalibrationChanged = { [weak self] in self?.rebuildEngine() }
        session.onPairingCompleted = { [weak self] preferences in
            guard let self else { return }
            self.preferences.phonePreferences = preferences
            self.rebuildEngine()
            self.publishToCloud()
            self.preferences.isSetupCompleted = false
            self.setupStep = .permissions
            self.sendSetupProgress(.permissions)
        }
    }

    private func sessionOpened() {
        cancelNotConnectedNotification()
        // Coming back after the link was down for a while: the iPhone was away (or the Mac slept).
        if isLocked, sessionClosedAt.map({ ContinuousClock.now - $0 > .seconds(30) }) ?? true {
            isProximityUnlockArmed = true
        }
        engine?.reset()
        // Changed in System Settings meanwhile: the status says it.
        cameraAccess = IntruderCamera.access
        session.send(.macStatus(macStatus))
        announcedImagesVersion = nil
        announceImagesIfNeeded()
        if isSetupPending, setupStep != .magic {
            // The iPhone may have been restarted meanwhile: it goes back to the current step.
            sendSetupProgress(setupStep == .firstTry ? .firstTry : .permissions)
        } else if let pendingSetupProgress {
            sendSetupProgress(pendingSetupProgress)
        }
    }

    private func sessionClosed() {
        dashboard.stop()
        proximity = nil
        isPhoneMoving = false
        sessionClosedAt = .now
        hasHandledApproach = false
        guard isPaired, !isSleeping else { return }
        if isLocked {
            transitions.hidePrompt()
            return
        }
        // Losing the link never locks the Mac (the app was closed, Bluetooth turned off…): only the
        // measured distance does. The user is told if the iPhone stays out of reach.
        scheduleNotConnectedNotification()
    }

    private func scheduleNotConnectedNotification() {
        disconnectionTask?.cancel()
        disconnectionTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled, let self, !self.session.connection.isConnected, self.isPaired else { return }
            self.notifier.post(
                identifier: MacNotifier.Identifier.status,
                title: String(localized: "Locky not connected"),
                body: String(localized: "Your iPhone is not connected to Locky.")
            )
        }
    }

    private func cancelNotConnectedNotification() {
        disconnectionTask?.cancel()
        disconnectionTask = nil
    }

    private func handle(_ message: LockyMessage) {
        switch message {
        case let .deviceStatus(status):
            let modelChanged: Bool = preferences.device?.modelIdentifier != status.modelIdentifier
            preferences.device = status
            apply(status.preferences)
            checkBattery(status.batteryLevel)
            if modelChanged {
                // New iPhone (or first status): render its picture for it.
                refreshImages(force: true)
            }
            announceImagesIfNeeded()
        case let .preferences(phonePreferences):
            apply(phonePreferences)
        case .cameraAccessRequest:
            allowCamera()
        case let .battery(level):
            preferences.device?.batteryLevel = level
            checkBattery(level)
        case let .motion(isMoving):
            isPhoneMoving = isMoving
        case let .call(isActive):
            isPhoneOnCall = isActive
        case .lock:
            lockMac(fromProximity: false)
        case let .unlock(password, _):
            Task { await performUnlock(password: password) }
        case .unpair:
            session.unpair(notifyPhone: false)
            resetAfterUnpairing()
        case let .setupProgress(progress):
            phoneSentSetupProgress(progress)
        case let .dashboard(isVisible):
            dashboard.setVisible(isVisible)
        case let .mediaCommand(command):
            dashboard.perform(command)
        default:
            break
        }
    }

    private func apply(_ phonePreferences: PhonePreferences) {
        let previous: PhonePreferences = preferences.phonePreferences
        preferences.phonePreferences = phonePreferences
        engine?.lockDistance = phonePreferences.lockDistance
        if phonePreferences.intrusionDetection, !previous.intrusionDetection {
            intrusionDetectionTurnedOn()
        } else if !phonePreferences.intrusionDetection, previous.intrusionDetection {
            isCameraRequestPending = false
            notifier.remove(MacNotifier.Identifier.camera)
            notifier.post(
                identifier: MacNotifier.Identifier.status,
                title: String(localized: "Locky - Intruders detection"),
                body: String(localized: "Intruders detection is now deactivated.")
            )
        }
    }

    // MARK: - Camera (intruder detection)

    /// Lets Locky use the camera: macOS asks the first time (on an unlocked Mac); after a refusal,
    /// System Settings opens on the Camera pane, the only place where it can be undone.
    func allowCamera() {
        refreshCameraAccess()
        switch cameraAccess {
        case .notDetermined:
            askForCamera()
        case .denied:
            IntruderCamera.openPrivacySettings()
            watchCameraAccess()
        case .authorized, .unavailable:
            break
        }
    }

    /// Reads the camera permission again and tells the iPhone when it changed.
    func refreshCameraAccess() {
        let access: CameraAccess = IntruderCamera.access
        guard access != cameraAccess else { return }
        cameraAccess = access
        session.send(.macStatus(macStatus))
        publishToCloud()
        if access == .authorized {
            notifier.remove(MacNotifier.Identifier.camera)
            if preferences.phonePreferences.intrusionDetection {
                notifyIntrusionDetectionOn()
            }
        }
    }

    /// The iPhone turned intruder detection on: make sure photos can be taken.
    private func intrusionDetectionTurnedOn() {
        refreshCameraAccess()
        switch cameraAccess {
        case .authorized:
            notifyIntrusionDetectionOn()
        case .notDetermined:
            askForCamera()
        case .denied:
            notifyCameraDenied()
        case .unavailable:
            notifier.post(
                identifier: MacNotifier.Identifier.status,
                title: String(localized: "Locky - Intruders detection"),
                body: String(localized: "Intruders detection is now activated. This Mac has no camera: attempts will be reported without a photo.")
            )
        }
    }

    /// macOS asks for the camera, on an unlocked Mac only: on the lock screen nobody could answer,
    /// the question waits for the next unlock.
    private func askForCamera() {
        guard !isLocked else {
            isCameraRequestPending = true
            return
        }
        NSApp.activate()
        Task {
            let isGranted: Bool = await IntruderCamera.requestAccess()
            // Granted: the change of permission announces the detection.
            refreshCameraAccess()
            if !isGranted, preferences.phonePreferences.intrusionDetection {
                notifyCameraDenied()
            }
        }
    }

    /// System Settings is open on the Camera pane: notice the change within seconds.
    private func watchCameraAccess() {
        cameraWatch?.cancel()
        cameraWatch = Task { [weak self] in
            for _ in 0..<90 {
                try? await Task.sleep(for: .seconds(2))
                guard let self, !Task.isCancelled else { return }
                self.refreshCameraAccess()
                if self.cameraAccess == .authorized {
                    return
                }
            }
        }
    }

    private func notifyIntrusionDetectionOn() {
        notifier.post(
            identifier: MacNotifier.Identifier.status,
            title: String(localized: "Locky - Intruders detection"),
            body: String(localized: "Intruders detection is now activated.")
        )
    }

    private func notifyCameraDenied() {
        notifier.post(
            identifier: MacNotifier.Identifier.camera,
            title: String(localized: "Locky - Intruders detection"),
            body: String(localized: "Locky can't use the camera: intruders won't be photographed. Click to allow it in System Settings.")
        )
    }

    private func checkBattery(_ level: Int?) {
        guard let level else { return }
        if level > 20 {
            lowBatteryWarned = false
        } else if !lowBatteryWarned {
            lowBatteryWarned = true
            notifier.post(
                identifier: MacNotifier.Identifier.battery,
                title: String(localized: "Low battery level on \(phoneName)!"),
                body: String(localized: "Your iPhone's battery is only \(level)% full. Charge it if you want to have Locky working.")
            )
        }
    }

    // MARK: - Proximity

    private func rebuildEngine() {
        guard let model = session.pairing?.distanceModel else {
            engine = nil
            return
        }
        engine = .init(model: model, lockDistance: preferences.phonePreferences.lockDistance)
    }

    private func received(rssi: Double) {
        guard session.connection.isConnected, isPaired else { return }
        if engine == nil {
            rebuildEngine()
        }
        guard var engine else { return }
        let context: ProximityContext = .init(
            isLocked: isLocked,
            isMoving: isPhoneMoving,
            isComputerInUse: !isLocked && SessionLocker.idleTime < Self.inUseIdleThreshold,
            isOnCall: isPhoneOnCall
        )
        let result: (reading: ProximityReading?, decision: ProximityDecision) = engine.ingest(rssi: rssi, context: context)
        self.engine = engine
        guard let reading = result.reading else { return }
        proximity = reading
        // Twice a second: the gauge of the iPhone follows the track of the Mac closely (a few bytes).
        if lastProximitySent.map({ ContinuousClock.now - $0 > .milliseconds(500) }) ?? true {
            lastProximitySent = .now
            session.send(.proximity(reading))
        }
        let lockDistance: Double = preferences.phonePreferences.lockDistance
        if isLocked, reading.distance > lockDistance {
            // The iPhone is away: the next approach may unlock.
            isProximityUnlockArmed = true
            hasHandledApproach = false
            transitions.hidePrompt()
        } else if isLocked, !isProximityUnlockArmed, reading.distance <= lockDistance * ProximityEngine.unlockDistanceRatio {
            // Locked with the iPhone right there (from the iPhone, the menu, a shortcut…).
            offerUnlockWithPhone()
        }
        switch result.decision {
        case .lock:
            if preferences.isAutoLockEnabled {
                logger.info("Proximity lock at \(reading.distance) m")
                lockMac(fromProximity: true)
            }
        case .unlock:
            proximityUnlock()
        case .stay:
            break
        }
    }

    private func proximityUnlock() {
        guard isLocked, !unlockInProgress, isProximityUnlockArmed, !hasHandledApproach else { return }
        hasHandledApproach = true
        let phonePreferences: PhonePreferences = preferences.phonePreferences
        if phonePreferences.unlockOnlyFromWatch {
            SessionLocker.wakeDisplay()
            showPrompt(mode: .watchOnly)
        } else if phonePreferences.unlockAutomatically, !isStoredPasswordRejected {
            if let lastPasswordRequest, ContinuousClock.now - lastPasswordRequest < .seconds(20) { return }
            lastPasswordRequest = .now
            session.send(.passwordRequest(.proximity))
        } else {
            // As in the original Locky: coming back wakes the Mac, the user unlocks it.
            logger.info("iPhone back without automatic unlocking: waking the display")
            SessionLocker.wakeDisplay()
            showPrompt(mode: .button)
        }
    }

    /// The Mac was locked while the iPhone stayed close: the lock screen offers to unlock with it
    /// right away, but nothing unlocks by itself since the user has just locked. With the display
    /// off, the offer waits for the lock screen to show up.
    private func offerUnlockWithPhone() {
        guard !unlockInProgress, !hasHandledApproach, SessionLocker.isDisplayAwake else { return }
        hasHandledApproach = true
        showPrompt(mode: preferences.phonePreferences.unlockOnlyFromWatch ? .watchOnly : .button)
    }

    private func showPrompt(mode: LockScreenPromptView.Mode) {
        guard preferences.isLockScreenOverlayEnabled else { return }
        transitions.showPrompt(deviceName: phoneName, mode: mode) { [weak self] in
            guard let self else { return }
            self.session.send(.passwordRequest(.lockScreenButton))
            self.showPrompt(mode: .waitingForPhone)
        }
    }

    // MARK: - Locking and unlocking

    private func lockMac(fromProximity: Bool) {
        // The animation plays for seconds before the session locks: the iPhone, still far, must
        // not start a second one meanwhile.
        guard !isLocked, lockingSince == nil else { return }
        let started: ContinuousClock.Instant = .now
        lockingSince = started
        isProximityUnlockArmed = fromProximity
        hasHandledApproach = false
        transitions.lock(animated: preferences.isLockAnimationEnabled, title: preferences.effectiveLockAnimationTitle) {
            SessionLocker.lock()
        }
        // Never stuck if the session did not lock (sessionDidLock clears it otherwise).
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(TransitionController.lockDuration + 5))
            if self?.lockingSince == started {
                self?.lockingSince = nil
            }
        }
    }

    private func performUnlock(password: String) async {
        guard SessionLocker.isScreenLocked else { return }
        guard !unlockInProgress else { return }
        guard AccessibilityPermission.isGranted else {
            notifier.post(
                identifier: MacNotifier.Identifier.status,
                title: String(localized: "Locky can't unlock your Mac"),
                body: String(localized: "Allow Locky in System Settings > Privacy & Security > Accessibility.")
            )
            return
        }
        unlockInProgress = true
        unlockRequestedAt = .now
        intrusions.stop()
        // Display asleep (the user walked away): wake it and let the lock screen appear first,
        // otherwise the animation plays while the screen is still lighting up and looks broken.
        let wasAsleep: Bool = !SessionLocker.isDisplayAwake
        SessionLocker.wakeDisplay()
        if wasAsleep {
            for _ in 0..<30 where !SessionLocker.isDisplayAwake {
                try? await Task.sleep(for: .milliseconds(100))
            }
            try? await Task.sleep(for: .milliseconds(800))
        }
        transitions.beginUnlock(animated: preferences.isLockAnimationEnabled, title: preferences.effectiveLockAnimationTitle)
        try? await Task.sleep(for: .milliseconds(700))
        guard isLocked, await SessionLocker.typePassword(password) else {
            // Unlocked meanwhile (Apple Watch, Touch ID…): nothing was typed.
            transitions.finishUnlock()
            unlockInProgress = false
            return
        }
        try? await Task.sleep(for: .seconds(4))
        if SessionLocker.isScreenLocked {
            logger.error("The session is still locked after typing the password")
            isStoredPasswordRejected = true
            session.send(.unlockFailed)
            transitions.finishUnlock()
            if preferences.phonePreferences.intrusionDetection, isPaired {
                intrusions.start()
            }
        }
        unlockInProgress = false
    }

    // MARK: - System events

    private func wireEvents() {
        events.onLock = { [weak self] in self?.sessionDidLock() }
        // The wings and the button leave as soon as the lock screen does, not once the desktop is
        // back (the unlock is reported later). At once: idle, macOS blanks the lock screen in one
        // go, and folding wings would float on the black screen.
        events.onLockScreenHidden = { [weak self] in
            guard let self, let mode = self.transitions.promptMode else { return }
            self.promptHiddenWithLockScreen = mode
            self.transitions.hidePrompt(animated: false)
        }
        events.onLockScreenShown = { [weak self] in
            guard let self, let mode = self.promptHiddenWithLockScreen else { return }
            self.promptHiddenWithLockScreen = nil
            // Display awake again, the iPhone still there: the same prompt comes back.
            var isPhoneAround: Bool = self.hasHandledApproach && self.session.connection.isConnected
            #if DEBUG
            if MacDemo.isLockScreenFilm, self.isLocked {
                self.showFilmPrompt()
                return
            }
            // The lock screen demo has no iPhone.
            isPhoneAround = isPhoneAround || MacDemo.isLockScreenOverlay
            #endif
            if self.isLocked, isPhoneAround {
                self.showPrompt(mode: mode)
            }
        }
        events.onUnlock = { [weak self] in self?.sessionDidUnlock() }
        events.onWillSleep = { [weak self] in
            guard let self else { return }
            self.isSleeping = true
            self.dashboard.stop()
            self.intrusions.stop()
            self.cancelNotConnectedNotification()
            self.session.stop()
        }
        events.onDidWake = { [weak self] in
            guard let self else { return }
            self.isSleeping = false
            self.isLocked = SessionLocker.isScreenLocked
            if self.isLocked, self.preferences.phonePreferences.intrusionDetection, self.isPaired {
                self.intrusions.start()
            }
            self.intrusions.didWake()
            self.session.start()
        }
        events.onSessionResignActive = { [weak self] in
            self?.cancelNotConnectedNotification()
            self?.session.stop()
        }
        events.onSessionBecomeActive = { [weak self] in self?.session.start() }
        events.start()
    }

    private func sessionDidLock() {
        isLocked = true
        lockingSince = nil
        lastPasswordRequest = nil
        session.send(.lockState(.locked))
        publishLockState(.locked)
        if preferences.phonePreferences.intrusionDetection, isPaired {
            intrusions.start()
        }
    }

    private func sessionDidUnlock() {
        isLocked = false
        promptHiddenWithLockScreen = nil
        isProximityUnlockArmed = false
        hasHandledApproach = false
        let unlockedByLocky: Bool = unlockRequestedAt.map { ContinuousClock.now - $0 < .seconds(10) } ?? false
        if setupStep == .firstTry, unlockedByLocky {
            // Before the lock state, so the iPhone goes straight to its own celebration.
            preferences.isSetupCompleted = true
            setupStep = .magic
            sendSetupProgress(.succeeded)
            onShowSetupWindow?()
        }
        if unlockRequestedAt != nil {
            isStoredPasswordRejected = false
        }
        refreshCameraAccess()
        if isCameraRequestPending {
            isCameraRequestPending = false
            if preferences.phonePreferences.intrusionDetection {
                askForCamera()
            }
        }
        intrusions.stop()
        transitions.finishUnlock()
        #if DEBUG
        lockScreenFilm?.markUnlocked()
        #endif
        if unlockedByLocky {
            preferences.unlockCount += 1
        }
        unlockRequestedAt = nil
        session.send(.lockState(.unlocked))
        publishLockState(.unlocked)
        refreshImages(force: false)
        if isPaired, !session.connection.isConnected {
            notifier.post(
                identifier: MacNotifier.Identifier.status,
                title: String(localized: "Locky not connected"),
                body: String(localized: "Your iPhone is not connected to Locky.")
            )
        }
    }

    // MARK: - Images and iCloud

    private func startBackgroundTasks() {
        backgroundTasks.forEach { $0.cancel() }
        backgroundTasks = [
            Task { [weak self] in
                // The Accessibility permission has no change notification.
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(2))
                    guard let self else { return }
                    let granted: Bool = AccessibilityPermission.isGranted
                    if granted != self.isAccessibilityGranted {
                        self.isAccessibilityGranted = granted
                    }
                    // Neither has the access to the files: follow it the same way (no prompt, the
                    // file is only checked once the user was asked).
                    self.refreshWallpaperAccess()
                }
            }
        ]
        // Wallpaper changes have none either: follow the store of the wallpaper agent, so the iPhone
        // gets the new wallpaper within a second (locked, the unlock refreshes it anyway).
        wallpaperWatcher.onChange = { [weak self] in
            guard let self, !self.isLocked else { return }
            self.refreshImages(force: false)
        }
        if !wallpaperWatcher.start() {
            logger.notice("Wallpaper store not found: checking the wallpaper periodically")
            backgroundTasks.append(Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    guard let self else { return }
                    guard !self.isLocked else { continue }
                    self.refreshImages(force: false)
                }
            })
        }
    }

    private func refreshImages(force: Bool) {
        let signature: String = MacImageRenderer.wallpaperSignature
        guard force || signature != wallpaperSignature else { return }
        wallpaperSignature = signature
        if preferences.isLockAnimationEnabled {
            transitions.prepareWallpaper()
        }
        let start: ContinuousClock.Instant = .now
        let rendered: MacImages = MacImageRenderer.render(
            phoneModelIdentifier: preferences.device?.modelIdentifier ?? session.peerModelIdentifier
        )
        guard rendered.version != images?.version else { return }
        logger.notice("New images \(rendered.version, privacy: .public) rendered in \(Self.milliseconds(since: start)) ms")
        images = rendered
        publishToCloud()
    }

    private static func milliseconds(since start: ContinuousClock.Instant) -> Int {
        let elapsed: Duration = .now - start
        return Int(elapsed.components.seconds * 1_000 + elapsed.components.attoseconds / 1_000_000_000_000_000)
    }

    /// Tells the iPhone to fetch the images from iCloud, once they are there and if it does not
    /// have them yet. A few bytes over Bluetooth instead of the images themselves.
    private func announceImagesIfNeeded() {
        guard
            let images,
            session.connection.isConnected,
            cloudImagesVersion == images.version,
            preferences.device?.macImagesVersion != images.version,
            announcedImagesVersion != images.version
        else { return }
        if session.send(.macImagesUpdated(version: images.version)) {
            announcedImagesVersion = images.version
            logger.notice("Announced images \(images.version, privacy: .public) to the iPhone")
        }
    }

    private func publishToCloud() {
        guard isPaired else { return }
        let record: CloudMacRecord = .init(
            status: macStatus,
            imagesVersion: images?.version,
            wallpaper: images?.wallpaper,
            userPicture: images?.userPicture,
            phoneImage: images?.phone
        )
        // A new wallpaper since the last publication of this run: no need to read the record first.
        let imagesAreNew: Bool = cloudImagesVersion != nil && record.imagesVersion != nil && record.imagesVersion != cloudImagesVersion
        let start: ContinuousClock.Instant = .now
        Task {
            do {
                try await CloudSync.shared.publish(record, imagesAreNew: imagesAreNew)
                logger.notice("""
                    Published to iCloud in \(Self.milliseconds(since: start)) ms: images \(record.imagesVersion ?? "none", privacy: .public), \
                    type \(record.status.deviceType ?? "unknown", privacy: .public), wallpaper \(record.wallpaper?.count ?? 0) B
                    """)
                if let version = record.imagesVersion {
                    cloudImagesVersion = version
                    announceImagesIfNeeded()
                }
            } catch {
                logger.notice("iCloud publication failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func publishLockState(_ state: LockState) {
        guard isPaired else { return }
        let macID: UUID = session.macID
        Task {
            do {
                try await CloudSync.shared.publishLockState(macID: macID, lockState: state, date: .now)
            } catch {
                publishToCloud()
            }
        }
    }

    private func reportIntrusion(photo: Data?) {
        guard preferences.phonePreferences.intrusionDetection else { return }
        let macID: UUID = session.macID
        let name: String = MacDeviceInfo.name
        let jpeg: Data? = photo
        Task {
            do {
                try await CloudSync.shared.uploadIntrusion(macID: macID, macName: name, date: .now, photo: jpeg)
            } catch {
                logger.error("Intrusion upload failed: \(error.localizedDescription)")
            }
        }
    }

    private func resetAfterUnpairing() {
        preferences.resetPairingRelatedValues()
        engine = nil
        proximity = nil
        cancelNotConnectedNotification()
        intrusions.stop()
        transitions.hidePrompt()
    }
}
