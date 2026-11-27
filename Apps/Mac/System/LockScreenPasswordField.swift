import AppKit
import ApplicationServices

/// The password field of the lock screen, read with the Accessibility API (granted to type the
/// password).
///
/// A secure field never tells its text, but its caret tells how many characters it holds: Locky
/// checks that the field took the whole password before validating it. A wrong password counts as
/// a failed attempt for macOS, which offers to reset the password after a few.
@MainActor
struct LockScreenPasswordField {
    private let element: AXUIElement

    /// The secure field of the lock screen, `nil` while macOS shows none: since macOS Sonoma it
    /// appears once a key is pressed. The focused one first, where the keys go.
    static func find() -> LockScreenPasswordField? {
        guard let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.loginwindow").first?.processIdentifier else {
            return nil
        }
        let application: AXUIElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.5)
        if let focused = value(of: application, kAXFocusedUIElementAttribute as String),
           CFGetTypeID(focused) == AXUIElementGetTypeID() {
            // swiftlint:disable:next force_cast
            let element: AXUIElement = focused as! AXUIElement
            if isSecureField(element) {
                return .init(element: element)
            }
        }
        var visited: Int = 0
        return search(application, depth: 0, visited: &visited).map { .init(element: $0) }
    }

    /// Gives the keyboard to the field, in case macOS left it elsewhere.
    func focus() {
        guard (Self.value(of: element, kAXFocusedAttribute as String) as? Bool) != true else { return }
        AXUIElementSetAttributeValue(element, kAXFocusedAttribute as CFString, kCFBooleanTrue)
    }

    /// Number of characters (UTF-16 units) up to the end of the selection, `nil` when the field does
    /// not tell. Right after typing, the caret stands after the last character: it is the length of
    /// what the field holds.
    var count: Int? {
        guard
            let value = Self.value(of: element, kAXSelectedTextRangeAttribute as String),
            CFGetTypeID(value) == AXValueGetTypeID()
        else { return nil }
        var range: CFRange = .init()
        // swiftlint:disable:next force_cast
        guard AXValueGetValue(value as! AXValue, .cfRange, &range) else { return nil }
        return range.location + range.length
    }

    private static func isSecureField(_ element: AXUIElement) -> Bool {
        (value(of: element, kAXSubroleAttribute as String) as? String) == kAXSecureTextFieldSubrole as String
            || (value(of: element, "AXIdentifier") as? String) == "UserPasswordTextField"
    }

    private static func search(_ element: AXUIElement, depth: Int, visited: inout Int) -> AXUIElement? {
        guard depth < 14, visited < 400 else { return nil }
        visited += 1
        if isSecureField(element) {
            return element
        }
        let children: [AXUIElement] = (value(of: element, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
        for child in children {
            if let field = search(child, depth: depth + 1, visited: &visited) {
                return field
            }
        }
        return nil
    }

    private static func value(of element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }
}
