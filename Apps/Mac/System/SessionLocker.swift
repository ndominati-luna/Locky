import AppKit
import ApplicationServices
import Carbon.HIToolbox
import Foundation
import IOKit.pwr_mgt
import OSLog

/// Low level control of the macOS session: lock it, wake the display, type the password on the
/// lock screen.
@MainActor
enum SessionLocker {
    private typealias LockScreenFunction = @convention(c) () -> Int32
    private static let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "SessionLocker")

    /// `SACLockScreenImmediate` from the private login framework: what the  menu "Lock Screen"
    /// item calls. Locks instantly whatever the screen saver password delay is.
    private static let lockScreenImmediate: LockScreenFunction? = PrivateSymbols.load(
        "SACLockScreenImmediate",
        from: PrivateSymbols.loginFramework,
        as: LockScreenFunction.self
    )

    /// `true` while the session is locked.
    static var isScreenLocked: Bool {
        guard let session = CGSessionCopyCurrentDictionary() as? [String: Any] else { return false }
        return session["CGSSessionScreenIsLocked"] as? Bool ?? false
    }

    /// `true` while the main display is on (the lock screen is visible when the session is locked).
    static var isDisplayAwake: Bool {
        CGDisplayIsAsleep(CGMainDisplayID()) == 0
    }

    /// Locks the session now.
    static func lock() {
        if let lockScreenImmediate {
            _ = lockScreenImmediate()
            return
        }
        // Fallback: the standard ⌃⌘Q shortcut.
        logger.notice("SACLockScreenImmediate unavailable, falling back to ⌃⌘Q")
        postKey(CGKeyCode(kVK_ANSI_Q), flags: [.maskCommand, .maskControl])
    }

    /// Wakes the display up (and keeps it awake for a moment) so the lock screen accepts input.
    /// Wakes the display and leaves the screen saver, like moving the mouse would.
    static func wakeDisplay() {
        var assertionID: IOPMAssertionID = 0
        IOPMAssertionDeclareUserActivity("Locky unlock" as CFString, kIOPMUserActiveLocal, &assertionID)
        // The screen saver ignores power assertions: a mouse move in place dismisses it (posting
        // events needs the Accessibility permission, granted to type the password).
        guard AccessibilityPermission.isGranted, let location = CGEvent(source: nil)?.location else { return }
        CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: location, mouseButton: .left)?.post(tap: .cghidEventTap)
    }

    /// Types the password in the lock screen field and validates it.
    ///
    /// Requires the Accessibility permission. Characters are injected as Unicode strings, so the
    /// password is typed correctly whatever the keyboard layout (the former implementation used
    /// AppleScript keystrokes, which broke with non QWERTY layouts and special characters).
    ///
    /// The lock state is checked again before every injected event: if the session got unlocked in
    /// the meantime (Apple Watch, Touch ID…), nothing more is typed, so the password can never end
    /// up in the focused field of a regular app.
    /// - Returns: `false` when typing was aborted.
    @discardableResult
    static func typePassword(_ password: String) async -> Bool {
        guard isScreenLocked else { return false }
        // Clear whatever is already in the field.
        postKey(CGKeyCode(kVK_ANSI_A), flags: .maskCommand)
        postKey(CGKeyCode(kVK_Delete))
        try? await Task.sleep(for: .milliseconds(80))

        let source: CGEventSource? = .init(stateID: .hidSystemState)
        let units: [UniChar] = Array(password.utf16)
        // The lock screen ignores keyboard events carrying more than 20 characters.
        for start in stride(from: 0, to: units.count, by: 20) {
            guard isScreenLocked else { return false }
            var chunk: [UniChar] = Array(units[start..<min(start + 20, units.count)])
            let keyDown: CGEvent? = .init(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Space), keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: &chunk)
            keyDown?.post(tap: .cghidEventTap)
            let keyUp: CGEvent? = .init(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Space), keyDown: false)
            keyUp?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(30))
        }
        try? await Task.sleep(for: .milliseconds(120))
        guard isScreenLocked else { return false }
        postKey(CGKeyCode(kVK_Return))
        return true
    }

    /// Seconds since the last keyboard, mouse or trackpad event (no permission needed).
    static var idleTime: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: ~0) ?? .null)
    }

    private static func postKey(_ key: CGKeyCode, flags: CGEventFlags = []) {
        let source: CGEventSource? = .init(stateID: .hidSystemState)
        let keyDown: CGEvent? = .init(keyboardEventSource: source, virtualKey: key, keyDown: true)
        keyDown?.flags = flags
        keyDown?.post(tap: .cghidEventTap)
        let keyUp: CGEvent? = .init(keyboardEventSource: source, virtualKey: key, keyDown: false)
        keyUp?.flags = flags
        keyUp?.post(tap: .cghidEventTap)
    }
}
