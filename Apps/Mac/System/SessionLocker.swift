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

    enum PasswordTyping {
        /// Typed and validated.
        case typed
        /// The session got unlocked meanwhile (Apple Watch, Touch ID…): typing stopped.
        case unlocked
        /// The field never held the whole password: emptied, not validated, so macOS counts no
        /// failed attempt.
        case notTaken
    }

    /// Types the password in the lock screen field and validates it.
    ///
    /// Requires the Accessibility permission. Characters are injected as Unicode strings, so the
    /// password is typed correctly whatever the keyboard layout (the former implementation used
    /// AppleScript keystrokes, which broke with non QWERTY layouts and special characters).
    ///
    /// Keys pressed while the lock screen is still lighting up, or leaving the screen saver, may be
    /// lost: a password missing characters would be refused, and macOS offers to reset the password
    /// after a few refusals. The field tells how many characters it holds: Locky validates only once
    /// it holds the whole password, typing it again otherwise.
    ///
    /// The lock state is checked again before every injected event: if the session got unlocked in
    /// the meantime (Apple Watch, Touch ID…), nothing more is typed, so the password can never end
    /// up in the focused field of a regular app.
    static func typePassword(_ password: String) async -> PasswordTyping {
        guard isScreenLocked else { return .unlocked }
        // Clears whatever is already in the field, and shows it: since macOS Sonoma it appears once a
        // key is pressed.
        clearField()
        var field: LockScreenPasswordField?
        for _ in 0..<15 {
            try? await Task.sleep(for: .milliseconds(100))
            field = LockScreenPasswordField.find()
            if field != nil { break }
        }
        guard let field else {
            logger.notice("Password field not found, typing without checking it")
            guard await inject(password) else { return .unlocked }
            try? await Task.sleep(for: .milliseconds(120))
            return validate()
        }
        field.focus()
        // Lengths the field may count, should it count otherwise than in UTF-16 units.
        let lengths: Set<Int> = [password.utf16.count, password.unicodeScalars.count, password.count]
        var previousCount: Int?
        for attempt in 1...3 {
            guard await empty(field) else { return .unlocked }
            guard await inject(password) else { return .unlocked }
            let count: Int? = await settledCount(of: field, expecting: lengths)
            // Unknown, or still nothing: the field does not tell, validate as Locky always did.
            guard let count, count > 0, !lengths.contains(count) else { return validate() }
            // The gap only, never the length of the password.
            let gap: Int = count - password.utf16.count
            logger.error("Typing attempt \(attempt): the password field is off by \(gap) characters")
            // The same twice: typing again changes nothing, the field counts otherwise.
            if count == previousCount {
                return validate()
            }
            previousCount = count
        }
        _ = await empty(field)
        return isScreenLocked ? .notTaken : .unlocked
    }

    /// Presses Return, unless the session got unlocked meanwhile.
    private static func validate() -> PasswordTyping {
        guard isScreenLocked else { return .unlocked }
        postKey(CGKeyCode(kVK_Return))
        return .typed
    }

    /// Select all, delete.
    private static func clearField() {
        postKey(CGKeyCode(kVK_ANSI_A), flags: .maskCommand)
        postKey(CGKeyCode(kVK_Delete))
    }

    /// Empties the field: select all and delete, then one delete per character left, should select
    /// all not work in it.
    /// - Returns: `false` when the session got unlocked meanwhile.
    private static func empty(_ field: LockScreenPasswordField) async -> Bool {
        guard let count = field.count, count > 0 else { return isScreenLocked }
        clearField()
        try? await Task.sleep(for: .milliseconds(80))
        if let left = field.count, left > 0 {
            for _ in 0..<left {
                guard isScreenLocked else { return false }
                postKey(CGKeyCode(kVK_Delete))
            }
            try? await Task.sleep(for: .milliseconds(80))
        }
        return isScreenLocked
    }

    /// What the field holds once the keys are handled: one of `lengths`, or whatever it settled on.
    private static func settledCount(of field: LockScreenPasswordField, expecting lengths: Set<Int>) async -> Int? {
        var count: Int?
        for _ in 0..<20 {
            try? await Task.sleep(for: .milliseconds(50))
            count = field.count
            guard let count else { return nil }
            if lengths.contains(count) { return count }
        }
        return count
    }

    /// Posts the password as Unicode strings.
    /// - Returns: `false` when the session got unlocked meanwhile.
    private static func inject(_ password: String) async -> Bool {
        let source: CGEventSource? = .init(stateID: .hidSystemState)
        for chunk in chunks(of: password) {
            guard isScreenLocked else { return false }
            var units: [UniChar] = Array(chunk.utf16)
            let keyDown: CGEvent? = .init(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Space), keyDown: true)
            keyDown?.keyboardSetUnicodeString(stringLength: units.count, unicodeString: &units)
            keyDown?.post(tap: .cghidEventTap)
            let keyUp: CGEvent? = .init(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_Space), keyDown: false)
            keyUp?.post(tap: .cghidEventTap)
            try? await Task.sleep(for: .milliseconds(30))
        }
        return true
    }

    /// The lock screen ignores keyboard events carrying more than 20 UTF-16 units: pieces of at most
    /// 20, never splitting a character (an emoji is two units, or more).
    private static func chunks(of password: String) -> [String] {
        var chunks: [String] = []
        var chunk: String = ""
        for character in password {
            if !chunk.isEmpty, chunk.utf16.count + character.utf16.count > 20 {
                chunks.append(chunk)
                chunk = ""
            }
            chunk.append(character)
        }
        if !chunk.isEmpty {
            chunks.append(chunk)
        }
        return chunks
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
