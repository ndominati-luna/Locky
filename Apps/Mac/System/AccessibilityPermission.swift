import AppKit
import ApplicationServices

/// The Accessibility permission lets Locky type the password on the lock screen.
///
/// The former app wrote directly into the TCC database with sudo; System Integrity Protection makes
/// that impossible (and it was never a good idea): the user grants it in System Settings.
@MainActor
enum AccessibilityPermission {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt (only the first time) and opens the right System Settings pane.
    static func request() {
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": true]
        if !AXIsProcessTrustedWithOptions(options as CFDictionary) {
            openSettings()
        }
    }

    static func openSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
