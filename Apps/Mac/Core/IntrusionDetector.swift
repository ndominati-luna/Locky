import Foundation
import LockyKit
import OSLog

/// Photographs people using the Mac while it is locked and the iPhone is away.
///
/// Like the former app: activity on a locked Mac (keyboard, mouse, trackpad) while the owner's
/// iPhone is not nearby triggers a photo; if nobody unlocks the Mac with Locky within 90 seconds,
/// the photo is uploaded to iCloud and the iPhone receives a push notification.
@MainActor
final class IntrusionDetector {
    /// Delay before reporting, leaves time for the owner to come back.
    static let reportDelay: Duration = .seconds(90)

    /// Tells whether the owner is nearby (then activity is not suspicious).
    var isOwnerNearby: () -> Bool = { false }
    var onReport: ((Data?) -> Void)?

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "Intrusion")
    private let camera: IntruderCamera = .init()
    private var monitorTask: Task<Void, Never>?
    private var reportTask: Task<Void, Never>?
    private var quietUntil: ContinuousClock.Instant = .now

    /// Starts watching (the Mac just locked).
    func start() {
        stop()
        // Ignore the activity right after locking or waking (the owner leaving, the lid opening…).
        quietUntil = .now + .seconds(20)
        monitorTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if ContinuousClock.now > self.quietUntil, SessionLocker.idleTime < 1.5, !self.isOwnerNearby() {
                    await self.intrusionSuspected()
                    return
                }
            }
        }
    }

    /// Owner unlocked or Mac sleeps: cancel everything.
    func stop() {
        monitorTask?.cancel()
        monitorTask = nil
        reportTask?.cancel()
        reportTask = nil
    }

    /// The Mac woke up: give the owner a moment.
    func didWake() {
        quietUntil = .now + .seconds(60)
    }

    private func intrusionSuspected() async {
        logger.notice("Activity on a locked Mac while the iPhone is away")
        let photo: Data? = await camera.takePhoto()
        reportTask = Task { [weak self] in
            try? await Task.sleep(for: Self.reportDelay)
            guard !Task.isCancelled, let self, SessionLocker.isScreenLocked else { return }
            self.onReport?(photo)
            // Keep watching for further attempts.
            self.start()
        }
    }
}
