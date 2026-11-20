import Foundation

/// Cross process notifications (no payload), used between the app and its extensions.
public enum DarwinNotificationCenter {
    /// Posts a notification.
    public static func post(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }
}

/// Observes a Darwin notification for as long as the instance lives.
public final class DarwinNotificationObserver: @unchecked Sendable {
    private let handler: @Sendable () -> Void

    /// - Parameters:
    ///   - name: Darwin notification name.
    ///   - handler: Called on the posting run loop (main thread for apps).
    public init(name: String, handler: @escaping @Sendable () -> Void) {
        self.handler = handler
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            { _, observer, _, _, _ in
                guard let observer else { return }
                Unmanaged<DarwinNotificationObserver>.fromOpaque(observer).takeUnretainedValue().handler()
            },
            name as CFString,
            nil,
            .deliverImmediately
        )
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }
}
