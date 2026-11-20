import AppKit
import Foundation

/// Session lock / unlock, sleep / wake and fast user switching events.
@MainActor
final class SystemEventsObserver {
    var onLock: (() -> Void)?
    var onUnlock: (() -> Void)?
    var onWillSleep: (() -> Void)?
    var onDidWake: (() -> Void)?
    var onSessionResignActive: (() -> Void)?
    var onSessionBecomeActive: (() -> Void)?
    var onScreensDidWake: (() -> Void)?
    /// The lock screen interface is shown (session locked, display on).
    var onLockScreenShown: (() -> Void)?
    /// The lock screen interface is going away: the first signal of an unlock (≈ 170 ms before the
    /// session is reported unlocked, measured on macOS 27.2); also sent when the display sleeps.
    var onLockScreenHidden: (() -> Void)?

    private var tokens: [any NSObjectProtocol] = []

    func start() {
        let distributed: DistributedNotificationCenter = .default()
        observe(distributed, "com.apple.screenIsLocked") { $0.onLock?() }
        observe(distributed, "com.apple.screenIsUnlocked") { $0.onUnlock?() }
        observe(distributed, "com.apple.screenLockUIIsShown") { $0.onLockScreenShown?() }
        observe(distributed, "com.apple.screenLockUIIsHidden") { $0.onLockScreenHidden?() }
        let workspace: NotificationCenter = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.willSleepNotification.rawValue) { $0.onWillSleep?() }
        observe(workspace, NSWorkspace.didWakeNotification.rawValue) { $0.onDidWake?() }
        observe(workspace, NSWorkspace.screensDidWakeNotification.rawValue) { $0.onScreensDidWake?() }
        observe(workspace, NSWorkspace.sessionDidResignActiveNotification.rawValue) { $0.onSessionResignActive?() }
        observe(workspace, NSWorkspace.sessionDidBecomeActiveNotification.rawValue) { $0.onSessionBecomeActive?() }
    }

    private func observe(_ center: NotificationCenter, _ name: String, handler: @escaping @MainActor (SystemEventsObserver) -> Void) {
        let token: any NSObjectProtocol = center.addObserver(forName: .init(name), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
        tokens.append(token)
    }
}
