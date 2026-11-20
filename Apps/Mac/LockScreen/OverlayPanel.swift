import AppKit
import SwiftUI

/// Borderless panel that never steals the keyboard focus: the password typed by Locky must keep
/// going to the lock screen field.
final class OverlayPanel: NSPanel {
    init(contentRect: NSRect, interactive: Bool) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .screenSaver
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
        ignoresMouseEvents = !interactive
        canBecomeVisibleWithoutLogin = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Hosts a SwiftUI view and shows the panel, above the lock screen when needed.
    func show<Content: View>(_ content: Content, aboveLockScreen: Bool) {
        let hostingView: FirstMouseHostingView<Content> = .init(rootView: content)
        hostingView.frame = NSRect(origin: .zero, size: frame.size)
        // Layer backed, for fades played by the render server (see `fadeOut`).
        hostingView.wantsLayer = true
        contentView = hostingView
        orderFrontRegardless()
        if aboveLockScreen {
            LockScreenSpace.shared.adopt(self)
        }
    }
}

extension OverlayPanel {
    /// Fades the content out with Core Animation, then hides the panel.
    ///
    /// The render server plays the animation by itself: it stays smooth while the app is busy,
    /// which happens right when the session locks or unlocks (an AppKit or SwiftUI animation, driven
    /// by the main thread, would freeze then disappear at once).
    func fadeOut(duration: TimeInterval) async {
        if let layer = contentView?.layer {
            let fade: CABasicAnimation = .init(keyPath: "opacity")
            fade.fromValue = layer.presentation()?.opacity ?? layer.opacity
            fade.toValue = 0
            fade.duration = duration
            fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(fade, forKey: "lockyFadeOut")
            layer.opacity = 0
        }
        try? await Task.sleep(for: .seconds(duration + 0.05))
        orderOut(nil)
    }

    /// Hides the panel at once, animation or not: for when what it stands on has already vanished.
    func hideNow() {
        contentView?.layer?.removeAllAnimations()
        alphaValue = 0
        orderOut(nil)
    }
}

/// Lets buttons react to the first click even though the panel is never key.
final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
