import Synchronization

/// Resumes a continuation exactly once, whichever comes first: a callback or a timeout.
final class OneShotContinuation<Value: Sendable>: Sendable {
    private let continuation: Mutex<CheckedContinuation<Value, Never>?>

    init(_ continuation: CheckedContinuation<Value, Never>) {
        self.continuation = .init(continuation)
    }

    func resume(returning value: Value) {
        continuation.withLock { pending in
            pending?.resume(returning: value)
            pending = nil
        }
    }
}
