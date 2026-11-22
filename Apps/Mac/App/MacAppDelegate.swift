import AppKit

/// Owns the model, the status menu and the windows, and starts everything as soon as the app
/// launches (Locky usually starts at login, with no window).
@MainActor
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    let model: MacAppModel = .init()
    private var windows: WindowManager?
    private var statusMenu: StatusMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Two Locky on one Mac fight for the iPhone: each one breaks the session of the other and
        // the link keeps dropping. The newest one wins (a build run from Xcode replaces the copy
        // started at login), once the other one has quit.
        var others: [NSRunningApplication] = NSRunningApplication
            .runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        #if DEBUG
        if MacDemo.isAnimationOnly {
            // Without Bluetooth: it competes with nobody.
            others = []
        }
        #endif
        guard !others.isEmpty else {
            startEverything()
            return
        }
        others.forEach { $0.terminate() }
        Task {
            for _ in 0..<30 where others.contains(where: { !$0.isTerminated }) {
                try? await Task.sleep(for: .milliseconds(100))
            }
            others.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
            startEverything()
        }
    }

    private func startEverything() {
        model.start()
        // Silent pushes of iCloud: settings the iPhone left out of reach.
        NSApp.registerForRemoteNotifications()
        let windows: WindowManager = .init(model: model)
        self.windows = windows
        statusMenu = .init(model: model, windows: windows)
        model.onShowSetupWindow = { [weak windows] in windows?.show(.pairing) }
        model.onCloseSetupWindow = { [weak windows] in windows?.close(.pairing) }
        var showsPairing: Bool = !model.isPaired || model.isSetupPending
        #if DEBUG
        if MacDemo.isAnimationOnly {
            showsPairing = false
        }
        #endif
        if showsPairing {
            windows.show(.pairing)
        }
        #if DEBUG
        if MacDemo.isPairingTour || MacDemo.setupStep != nil {
            windows.show(.pairing)
        }
        if MacDemo.isAnimationWindow {
            windows.show(.animation)
        }
        if MacDemo.isReleaseNotesWindow {
            windows.show(.releaseNotes)
        }
        if MacDemo.isAboutWindow {
            windows.show(.about)
        }
        if MacDemo.isStoryWindow {
            windows.show(.story)
        }
        #endif
    }

    func application(_ application: NSApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        model.remoteNotificationsDidRegister()
    }

    func application(_ application: NSApplication, didFailToRegisterForRemoteNotificationsWithError error: any Error) {
        model.remoteNotificationsDidFail(error)
    }

    func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        model.didReceiveRemoteNotification(userInfo)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// Forgets what is playing in iCloud before quitting.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await model.prepareForTermination()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
