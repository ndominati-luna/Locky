import Foundation
import LockyKit
import OSLog
import WatchConnectivity

/// Keeps the Apple Watch app up to date and receives its commands.
@MainActor
final class WatchBridge: NSObject {
    /// Executes a command coming from the Watch. Returns `true` when it was sent to the Mac.
    var onCommand: ((LockyCommand) async -> Bool)?

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "WatchBridge")
    private var session: WCSession?
    private var pendingContext: [String: Any]?

    func start() {
        guard WCSession.isSupported() else { return }
        let session: WCSession = .default
        session.delegate = self
        session.activate()
        self.session = session
    }

    /// Sends the latest state. The Watch fetches the images from iCloud by itself: the version only
    /// tells it that new ones are there.
    func publish(_ snapshot: LockySnapshot, imagesVersion: String?) {
        guard let session, let snapshotData = try? JSONEncoder().encode(snapshot) else { return }
        var context: [String: Any] = [WatchMessageKey.snapshot: snapshotData]
        context[WatchMessageKey.imagesVersion] = imagesVersion
        guard session.activationState == .activated, session.isPaired, session.isWatchAppInstalled else {
            pendingContext = context
            return
        }
        do {
            try session.updateApplicationContext(context)
        } catch {
            logger.error("Watch context update failed: \(error.localizedDescription)")
        }
    }

    private func flushPendingContext() {
        guard let session, let pendingContext, session.activationState == .activated else { return }
        try? session.updateApplicationContext(pendingContext)
        self.pendingContext = nil
    }
}

extension WatchBridge: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: (any Error)?
    ) {
        Task { @MainActor in flushPendingContext() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        let rawCommand: String? = message[WatchMessageKey.command] as? String
        nonisolated(unsafe) let replyHandler: ([String: Any]) -> Void = replyHandler
        Task { @MainActor in
            guard let rawCommand, let command = LockyCommand(rawValue: rawCommand) else {
                replyHandler([WatchMessageKey.success: false])
                return
            }
            let success: Bool = await onCommand?(command) ?? false
            replyHandler([WatchMessageKey.success: success])
        }
    }
}
