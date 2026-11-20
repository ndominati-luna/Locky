import Foundation
import LockyKit
import WidgetKit

/// Publishes the state to widgets and controls, and receives the commands they queue.
@MainActor
final class WidgetBridge {
    var onCommand: ((PendingCommand) -> Void)?
    private var observer: DarwinNotificationObserver?
    private var lastSnapshot: LockySnapshot?

    func start() {
        observer = DarwinNotificationObserver(name: SharedCommandQueue.notificationName) { [weak self] in
            Task { @MainActor in self?.drainCommands() }
        }
        drainCommands()
    }

    /// Executes the commands queued while the app was not listening.
    func drainCommands() {
        for command in SharedCommandQueue.drain() {
            onCommand?(command)
        }
    }

    func publish(_ snapshot: LockySnapshot) {
        var comparable: LockySnapshot = snapshot
        comparable.updatedAt = lastSnapshot?.updatedAt ?? snapshot.updatedAt
        guard comparable != lastSnapshot else { return }
        lastSnapshot = snapshot
        SharedStore.save(snapshot)
        reloadAll()
    }

    func reloadAll() {
        WidgetCenter.shared.reloadAllTimelines()
        ControlCenter.shared.reloadAllControls()
    }
}
