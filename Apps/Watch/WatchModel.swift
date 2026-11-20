import Foundation
import LockyKit
import Observation
import OSLog
import WatchConnectivity
import UIKit
import WatchKit
import WidgetKit

/// State of the Watch app.
///
/// The Watch is autonomous for what iCloud knows: it fetches the images and the lock state of the
/// Mac by itself (when opened, on the silent push of iCloud, in background refreshes). The iPhone
/// adds what only it knows (live connection to the Mac) and relays the lock and unlock commands.
@MainActor
@Observable
final class WatchModel: NSObject {
    /// Shared with the app delegate, which receives the pushes and background refreshes.
    static let shared: WatchModel = .init()

    /// Identifier of the background refresh task.
    static let refreshTaskIdentifier: String = "locky-refresh"

    private(set) var snapshot: LockySnapshot = SharedStore.snapshot()
    /// Exact type and model of the Mac: its image in the catalog embedded in the Watch app.
    private(set) var deviceType: String? = SharedStore.deviceType
    private(set) var macModel: String? = SharedStore.model
    /// Wallpaper of the Mac: in its screen, and blurred behind it like in the other apps.
    private(set) var wallpaper: Data? = SharedStore.wallpaper {
        didSet { wallpaperImage = wallpaper.flatMap(UIImage.init(data:)) }
    }
    /// The wallpaper decoded once, for the screen of the Mac.
    private(set) var wallpaperImage: UIImage? = SharedStore.wallpaper.flatMap(UIImage.init(data:))

    /// The Mac from the catalog of the Watch app, its screen transparent.
    var macFrame: MacFrame? {
        MacFrame.catalog(deviceType: deviceType, model: macModel)
    }
    private(set) var isSending: Bool = false
    private(set) var isPhoneReachable: Bool = false
    var errorMessage: String?

    @ObservationIgnored private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "Watch")
    @ObservationIgnored private var session: WCSession?
    @ObservationIgnored private var refreshTask: Task<Void, Never>?

    func start() {
        #if DEBUG
        if WatchDemo.isEnabled {
            startDemo()
            return
        }
        #endif
        guard session == nil, WCSession.isSupported() else { return }
        let session: WCSession = .default
        session.delegate = self
        session.activate()
        self.session = session
    }

    /// Locks or unlocks the Mac through the iPhone.
    func toggle() {
        send(snapshot.lockState == .locked ? .unlock : .lock)
    }

    func send(_ command: LockyCommand) {
        #if DEBUG
        if WatchDemo.isEnabled {
            simulateDemoCommand(command)
            return
        }
        #endif
        guard let session, session.activationState == .activated else {
            errorMessage = String(localized: "Your iPhone is not reachable.")
            return
        }
        isSending = true
        // Sendable handlers: WatchConnectivity calls them on its own queue. Without it they would
        // inherit the main actor isolation, and Swift traps as soon as they run elsewhere.
        session.sendMessage(
            [WatchMessageKey.command: command.rawValue],
            replyHandler: { @Sendable [weak self] reply in
                let success: Bool = reply[WatchMessageKey.success] as? Bool ?? false
                Task { @MainActor in
                    self?.isSending = false
                    if !success {
                        self?.errorMessage = String(localized: "Your Mac is not connected to your iPhone.")
                    }
                }
            },
            errorHandler: { @Sendable [weak self] error in
                Task { @MainActor in
                    self?.isSending = false
                    self?.errorMessage = error.localizedDescription
                }
            }
        )
    }

    // MARK: - iCloud

    /// Fetches the Mac from iCloud. Concurrent calls share the same fetch.
    func refreshFromCloud() async {
        #if DEBUG
        guard !WatchDemo.isEnabled else { return }
        #endif
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task: Task<Void, Never> = Task {
            do {
                guard let record = try await CloudSync.shared.fetchLatestMac(knownImagesVersion: SharedStore.imagesVersion) else { return }
                apply(cloudRecord: record)
                // The status subscription of the iPhone serves the Watch too; saving it again is harmless.
                try? await CloudSync.shared.registerSubscriptions(intrusionAlertKey: nil)
            } catch {
                logger.notice("iCloud refresh failed: \(error.localizedDescription)")
            }
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    /// Asks watchOS for the next background refresh, about every half hour.
    static func scheduleBackgroundRefresh() {
        WKApplication.shared().scheduleBackgroundRefresh(
            withPreferredDate: .now.addingTimeInterval(30 * 60),
            userInfo: refreshTaskIdentifier as NSString
        ) { _ in }
    }

    private func apply(cloudRecord: CloudMacRecord) {
        var changed: Bool = false
        let status: MacStatus = cloudRecord.status
        if status.deviceType != deviceType || status.model != macModel {
            deviceType = status.deviceType
            macModel = status.model
            SharedStore.deviceType = status.deviceType
            SharedStore.model = status.model
        }
        if let version = cloudRecord.imagesVersion, version != SharedStore.imagesVersion, cloudRecord.isComplete {
            wallpaper = cloudRecord.wallpaper
            SharedStore.wallpaper = cloudRecord.wallpaper
            SharedStore.imagesVersion = version
            changed = true
        }
        // The lock state of iCloud when it is newer than the one relayed by the iPhone (out of reach).
        if !snapshot.isPaired || status.lockStateDate > snapshot.lockStateDate ?? .distantPast {
            snapshot.isPaired = true
            snapshot.macName = status.name
            snapshot.family = status.family
            snapshot.lockState = status.lockState
            snapshot.lockStateDate = status.lockStateDate
            snapshot.isAutoLockEnabled = status.isAutoLockEnabled
            snapshot.updatedAt = .now
            SharedStore.save(snapshot)
            changed = true
        }
        if changed {
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: - Demo

    #if DEBUG
    /// Fills the model and the App Group (for the complications) with sample data.
    private func startDemo() {
        snapshot = WatchDemo.snapshot
        deviceType = WatchDemo.deviceType
        macModel = WatchDemo.model
        wallpaper = WatchDemo.wallpaper
        isPhoneReachable = true
        SharedStore.save(snapshot)
        SharedStore.deviceType = deviceType
        SharedStore.model = macModel
        SharedStore.wallpaper = wallpaper
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The Mac answers after a second, as through the iPhone.
    private func simulateDemoCommand(_ command: LockyCommand) {
        isSending = true
        Task {
            try? await Task.sleep(for: .seconds(1))
            switch command {
            case .lock: snapshot.lockState = .locked
            case .unlock: snapshot.lockState = .unlocked
            case .toggle: snapshot.lockState = snapshot.lockState == .locked ? .unlocked : .locked
            }
            snapshot.lockStateDate = .now
            SharedStore.save(snapshot)
            isSending = false
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    #endif

    // MARK: - iPhone

    private func apply(context: [String: Any]) {
        if
            let data = context[WatchMessageKey.snapshot] as? Data,
            let snapshot = try? JSONDecoder().decode(LockySnapshot.self, from: data)
        {
            self.snapshot = snapshot
            SharedStore.save(snapshot)
            WidgetCenter.shared.reloadAllTimelines()
        }
        // New images in iCloud: fetch them now rather than waiting for the push.
        if let version = context[WatchMessageKey.imagesVersion] as? String, version != SharedStore.imagesVersion {
            Task { await refreshFromCloud() }
        }
    }
}

extension WatchModel: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        let context: [String: Any] = session.receivedApplicationContext
        nonisolated(unsafe) let sendableContext: [String: Any] = context
        let reachable: Bool = session.isReachable
        Task { @MainActor in
            apply(context: sendableContext)
            isPhoneReachable = reachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        let reachable: Bool = session.isReachable
        Task { @MainActor in isPhoneReachable = reachable }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        nonisolated(unsafe) let context: [String: Any] = applicationContext
        Task { @MainActor in apply(context: context) }
    }
}
