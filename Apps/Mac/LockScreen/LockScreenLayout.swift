import AppKit
import ApplicationServices

/// Where macOS draws the user picture and the password field of the lock screen, read with the
/// Accessibility API (granted to Locky to type the password). Since macOS Sonoma they sit at the
/// bottom of the screen, at places that change with the version and the screen: Locky frames the
/// picture with its wings and puts its button under the field.
enum LockScreenLayout {
    struct Anchors: CustomStringConvertible {
        /// User picture, in AppKit screen coordinates (read, or deduced from the name).
        var avatar: CGRect?
        /// Message of the lock screen, above the picture (System Settings > Lock Screen).
        var message: CGRect?
        /// Name of the user, under the picture.
        var name: CGRect?
        /// Password field, only there once the keyboard is used: it takes the place of the name.
        var passwordField: CGRect?
        /// Name and hint under the picture, in AppKit screen coordinates.
        var labels: [CGRect] = []
        /// Every element read, for ``covering(_:)``.
        fileprivate var elements: [Element] = []

        /// What macOS shows over `picture` (see ``LockScreenLayout/covering(_:mainHeight:)``).
        func covering(_ picture: CGRect) -> [String] {
            LockScreenLayout.covering(picture, in: elements)
        }

        /// Everything macOS draws for the login, to keep Locky's button clear of it.
        var loginBlock: CGRect? {
            ([avatar, passwordField].compactMap { $0 } + labels).reduce(nil) { union, rect in union?.union(rect) ?? rect }
        }

        /// Bottom of the name, or of the password field under it.
        var loginBottom: CGFloat? {
            [name?.minY, passwordField?.minY].compactMap { $0 }.min()
        }

        /// Bottom of the hint line under the name ("Touch ID or Enter Password"), whether macOS
        /// shows it yet or not: it comes and goes with Touch ID and the keyboard.
        var hintBottom: CGFloat? {
            guard let loginBottom else { return nil }
            return ([loginBottom - LockScreenLayout.nameToHintBottom] + labels.map(\.minY)).min()
        }

        var description: String {
            "avatar: \(avatar.map { NSStringFromRect($0) } ?? "-"), message: \(message.map { NSStringFromRect($0) } ?? "-"), password: \(passwordField.map { NSStringFromRect($0) } ?? "-"), labels: \(labels.map { NSStringFromRect($0) })"
        }
    }

    /// Picture of the lock screen of macOS 26 and later, which do not expose it: it grows with the
    /// height of the screen it is drawn on, while the texts keep their size. Measured pixel by pixel
    /// on macOS 27.2, other heights follow the line through both measures (to the half point).
    static func avatarDiameter(on screen: NSScreen?) -> CGFloat {
        let small: (height: CGFloat, diameter: CGFloat) = (1169, 56.5) // 14" MacBook Pro, "More Space"
        let large: (height: CGFloat, diameter: CGFloat) = (1440, 72) // 49" 5120 × 1440 display
        let height: CGFloat = screen?.frame.height ?? large.height
        let slope: CGFloat = (large.diameter - small.diameter) / (large.height - small.height)
        let diameter: CGFloat = small.diameter + (height - small.height) * slope
        return (min(max(diameter, 40), 120) * 2).rounded() / 2
    }

    /// Where macOS 26 and later draw the user picture, for when the Accessibility API cannot tell
    /// (not granted yet): centered, at a height measured on macOS 27.2 on both screens of
    /// ``avatarDiameter(on:)``, other heights following the line through both measures.
    static func estimatedAvatar(on screen: NSScreen) -> CGRect {
        let small: (height: CGFloat, centerY: CGFloat) = (1169, 158.25) // 14" MacBook Pro, "More Space"
        let large: (height: CGFloat, centerY: CGFloat) = (1440, 182) // 49" 5120 × 1440 display
        let slope: CGFloat = (large.centerY - small.centerY) / (large.height - small.height)
        let centerY: CGFloat = small.centerY + (screen.frame.height - small.height) * slope
        let diameter: CGFloat = avatarDiameter(on: screen)
        return .init(
            x: screen.frame.midX - diameter / 2,
            y: screen.frame.minY + centerY - diameter / 2,
            width: diameter,
            height: diameter
        )
    }

    /// From the top of the name to the bottom of the picture, whatever the screen.
    private static let avatarToName: CGFloat = 14
    /// From the bottom of the name to the bottom of the hint line: a 12 pt gap and a 17 pt line
    /// (measured on macOS 27.2).
    static let nameToHintBottom: CGFloat = 29

    static func anchors() -> Anchors {
        let elements: [Element] = loginWindowElements(mainHeight: NSScreen.screens.first?.frame.height)
        var anchors: Anchors = anchors(from: elements)
        anchors.elements = elements
        return anchors
    }

    /// What macOS writes or draws over `picture` (texts, buttons, images), the picture itself aside,
    /// read again: one call to loginwindow per attribute, to make off the main thread. After failed
    /// passwords (or with its ? button), macOS puts a message offering to reset the password where
    /// the picture was: the wings must not frame it.
    /// - Parameter mainHeight: Height of the main screen, read on the main thread.
    static func covering(_ picture: CGRect, mainHeight: CGFloat) -> [String] {
        covering(picture, in: loginWindowElements(mainHeight: mainHeight))
    }

    /// Roles of what macOS writes or draws, as opposed to the windows and groups holding them, which
    /// span the picture anyway.
    private static let contentRoles: Set<String> = [
        kAXStaticTextRole as String,
        kAXTextAreaRole as String,
        kAXTextFieldRole as String,
        kAXButtonRole as String,
        kAXImageRole as String,
        "AXLink",
    ]

    fileprivate static func covering(_ picture: CGRect, in elements: [Element]) -> [String] {
        // A few points inside: the name and the message of the lock screen come close to the picture.
        let area: CGRect = picture.insetBy(dx: 4, dy: 4)
        return elements
            .filter { contentRoles.contains($0.role) && $0.frame.intersects(area) && !isPicture($0.frame, picture) }
            .map(\.description)
    }

    /// The picture itself, when macOS exposes it.
    private static func isPicture(_ frame: CGRect, _ picture: CGRect) -> Bool {
        abs(frame.midX - picture.midX) < 8 && abs(frame.midY - picture.midY) < 8
            && abs(frame.width - picture.width) < 16 && abs(frame.height - picture.height) < 16
    }

    private static func anchors(from elements: [Element]) -> Anchors {
        let name: CGRect? = elements.first { $0.identifier == "FocusedUser" }?.frame
        let passwordField: CGRect? = elements.first { $0.identifier == "UserPasswordTextField" }?.frame
        let message: CGRect? = elements.first { $0.role == kAXTextAreaRole as String }?.frame
        // Texts under the name (hint "Touch ID or Enter Password"…), centered on it.
        let labels: [CGRect] = name.map { name in
            [name] + elements
                .filter { $0.role == kAXStaticTextRole as String && $0.frame.maxY <= name.minY + 2 && abs($0.frame.midX - name.midX) < 40 && name.minY - $0.frame.maxY < 60 }
                .map(\.frame)
        } ?? []
        // A round image when macOS exposes one (older versions).
        if let image = elements.first(where: { $0.role == kAXImageRole as String && abs($0.frame.width - $0.frame.height) < 6 && (40...400).contains($0.frame.width) && $0.frame.midY < (NSScreen.screens.first?.frame.height ?? 0) / 2 }) {
            return .init(avatar: image.frame, message: message, name: name, passwordField: passwordField, labels: labels)
        }
        guard let name else { return .init(avatar: nil, message: message, name: nil, passwordField: passwordField, labels: labels) }
        // The name is laid out by its text and may be off by half a point: the picture is centered on
        // the screen.
        let screen: NSScreen? = NSScreen.screens.first { $0.frame.intersects(name) }
        let centerX: CGFloat = screen?.frame.midX ?? name.midX
        let diameter: CGFloat = avatarDiameter(on: screen)
        let avatar: CGRect = .init(
            x: centerX - diameter / 2,
            y: name.maxY + avatarToName,
            width: diameter,
            height: diameter
        )
        return .init(avatar: avatar, message: message, name: name, passwordField: passwordField, labels: labels)
    }

    #if DEBUG
    /// Every element of the lock screen, for calibration (`-LockyDemoLockScreenProbe YES`).
    static func dump() -> String {
        loginWindowElements(mainHeight: NSScreen.screens.first?.frame.height).map(\.description).joined(separator: "\n")
    }
    #endif

    // MARK: - Accessibility

    fileprivate struct Element: CustomStringConvertible {
        let role: String
        let subrole: String?
        let identifier: String?
        /// AppKit screen coordinates (origin at the bottom left of the main screen).
        let frame: CGRect

        /// Never the text: it may name the user.
        var description: String {
            "\(role) \(subrole ?? "") \(identifier ?? "") \(NSStringFromRect(frame))"
        }
    }

    /// - Parameter mainHeight: Height of the main screen, read on the main thread: the elements may
    ///   be read on another one.
    private static func loginWindowElements(mainHeight: CGFloat?) -> [Element] {
        guard
            let mainHeight,
            AXIsProcessTrusted(),
            let pid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.loginwindow").first?.processIdentifier
        else { return [] }
        let application: AXUIElement = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(application, 0.5)
        var elements: [Element] = []
        collect(application, depth: 0, mainHeight: mainHeight, into: &elements)
        return elements
    }

    private static func collect(_ element: AXUIElement, depth: Int, mainHeight: CGFloat, into elements: inout [Element]) {
        guard depth < 14, elements.count < 400 else { return }
        if let role = value(of: element, kAXRoleAttribute as String) as? String, let frame = frame(of: element, mainHeight: mainHeight) {
            elements.append(.init(
                role: role,
                subrole: value(of: element, kAXSubroleAttribute as String) as? String,
                identifier: value(of: element, "AXIdentifier") as? String,
                frame: frame
            ))
        }
        let children: [AXUIElement] = (value(of: element, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
        for child in children {
            collect(child, depth: depth + 1, mainHeight: mainHeight, into: &elements)
        }
    }

    private static func value(of element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    /// Accessibility frames start at the top left of the main screen; AppKit ones at the bottom left.
    private static func frame(of element: AXUIElement, mainHeight: CGFloat) -> CGRect? {
        guard
            let positionValue = value(of: element, kAXPositionAttribute as String),
            let sizeValue = value(of: element, kAXSizeAttribute as String),
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else { return nil }
        var position: CGPoint = .zero
        var size: CGSize = .zero
        // swiftlint:disable:next force_cast
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        // swiftlint:disable:next force_cast
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        guard size.width > 0, size.height > 0 else { return nil }
        return .init(x: position.x, y: mainHeight - position.y - size.height, width: size.width, height: size.height)
    }
}
