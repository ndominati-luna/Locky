import AppKit

/// A menu item running a closure.
@MainActor
final class ClosureMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(_ title: String, image: String? = nil, keyEquivalent: String = "", state: NSControl.StateValue = .off, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: keyEquivalent)
        target = self
        self.state = state
        if let image {
            self.image = NSImage(systemSymbolName: image, accessibilityDescription: nil)
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func runHandler() {
        handler()
    }
}
