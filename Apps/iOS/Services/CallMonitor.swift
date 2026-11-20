import CallKit
import Foundation

/// Tells whether a phone or VoIP call is in progress (the Mac then locks less eagerly).
@MainActor
final class CallMonitor: NSObject {
    var onChange: ((Bool) -> Void)?
    private(set) var isOnCall: Bool = false
    private let observer: CXCallObserver = .init()

    override init() {
        super.init()
        observer.setDelegate(self, queue: nil)
        isOnCall = observer.calls.contains { !$0.hasEnded }
    }

    private func refresh() {
        let onCall: Bool = observer.calls.contains { !$0.hasEnded }
        guard onCall != isOnCall else { return }
        isOnCall = onCall
        onChange?(onCall)
    }
}

extension CallMonitor: CXCallObserverDelegate {
    nonisolated func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        MainActor.assumeIsolated { refresh() }
    }
}
