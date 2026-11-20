import AppKit
import OSLog
import SwiftUI

/// Shows the lock screen prompt and the lock / unlock animations.
@MainActor
final class TransitionController {
    /// The desktop fades into the wallpaper.
    static let fadeDuration: TimeInterval = 0.7
    /// The iris closes on the ring of the logo.
    static let irisDuration: TimeInterval = 1.0
    /// Fade, iris, then the logo and its title, before the session locks.
    static let lockDuration: TimeInterval = fadeDuration + 3.1
    /// The logo flies away, revealing the desktop.
    static let unlockDuration: TimeInterval = 1.4

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "LockScreen")
    private var promptPanel: OverlayPanel?
    private var wingsPanel: OverlayPanel?
    private var promptTask: Task<Void, Never>?
    private var promptContent: LockScreenPromptView?
    private var promptState: LockScreenPromptState?
    private var transitionPanels: [OverlayPanel] = []
    /// Locking animation, until the logo has faded into the lock screen.
    private var lockTask: Task<Void, Never>?
    /// Wallpaper of each display at its resolution, decoded once per wallpaper. It stands for the
    /// desktop in the animations: capturing the screen would require the Screen Recording permission.
    private var wallpaperCache: [CGDirectDisplayID: (signature: String, image: NSImage)] = [:]

    // MARK: - Lock screen prompt

    /// Wings around the user picture and Unlock button, above the lock screen.
    /// - Parameter onUnlock: Same as the Unlock button of the iPhone.
    func showPrompt(deviceName: String, mode: LockScreenPromptView.Mode, onUnlock: @escaping () -> Void) {
        let state: LockScreenPromptState = promptState ?? .init()
        promptState = state
        let content: LockScreenPromptView = .init(deviceName: deviceName, mode: mode, state: state, onUnlock: onUnlock)
        promptContent = content
        if let promptPanel {
            // Already on screen: update the button, keep the wings.
            promptPanel.show(content, aboveLockScreen: true)
            return
        }
        guard promptTask == nil else { return }
        promptTask = Task {
            // Locked by Locky: the logo fades into the lock screen first.
            await lockTask?.value
            var anchors: LockScreenLayout.Anchors = LockScreenLayout.anchors()
            if anchors.avatar == nil {
                // Just woken up: the lock screen may still be appearing.
                try? await Task.sleep(for: .milliseconds(700))
                anchors = LockScreenLayout.anchors()
            }
            promptTask = nil
            guard !Task.isCancelled, let content = promptContent else { return }
            logger.info("Lock screen \(anchors.description, privacy: .public)")
            placePrompt(content, anchors: anchors)
        }
    }

    /// Mode of the prompt on screen (or being placed), `nil` without prompt.
    var promptMode: LockScreenPromptView.Mode? {
        promptContent?.mode
    }

    /// The wings fold away and the button fades out, then their windows close.
    /// - Parameter animated: `false` when the lock screen has already vanished (macOS blanks it at
    ///   once when idle): the wings leave with it instead of floating on the black screen.
    func hidePrompt(animated: Bool = true) {
        promptTask?.cancel()
        promptTask = nil
        promptContent = nil
        let panels: [OverlayPanel] = [promptPanel, wingsPanel].compactMap { $0 }
        promptPanel = nil
        wingsPanel = nil
        // The wings fold away (SwiftUI, when the app has time to draw it) while Core Animation fades
        // everything out (always smooth).
        promptState?.isDismissed = true
        promptState = nil
        guard !panels.isEmpty else { return }
        guard animated else {
            panels.forEach { $0.hideNow() }
            return
        }
        Task {
            await fadeOut(panels, duration: 0.2)
        }
    }

    private func placePrompt(_ content: LockScreenPromptView, anchors: LockScreenLayout.Anchors) {
        // macOS draws the login on the primary display (the one with the menu bar).
        let screen: NSScreen? = anchors.avatar.flatMap { avatar in NSScreen.screens.first { $0.frame.intersects(avatar) } }
            ?? NSScreen.screens.first
        guard let screen else { return }
        // The picture of macOS where it says it is, or where macOS 27 draws it when it does not tell
        // (Accessibility not granted yet). On the lock screen the wings always frame the real
        // picture, never a copy: Locky draws it only on the desktop (preview of the prompt).
        let avatar: CGRect = anchors.avatar ?? LockScreenLayout.estimatedAvatar(on: screen)
        var picture: NSImage?
        if anchors.avatar == nil, !SessionLocker.isScreenLocked {
            picture = MacImageRenderer.userPicture().map { NSImage(cgImage: $0, size: .zero) }
                ?? NSImage(systemSymbolName: "person.crop.circle.fill", accessibilityDescription: nil)
        }
        let wings: OverlayPanel = .init(contentRect: Self.wingsFrame(around: avatar), interactive: false)
        wings.show(LockScreenWings(avatarDiameter: avatar.width, picture: picture, state: content.state), aboveLockScreen: true)
        wingsPanel = wings
        // The button goes under the name and the hint line of macOS, clear of the wings. Typing the
        // password replaces the name with the field, at the same place.
        let wingsBottom: CGFloat = avatar.midY - LockScreenWings.depthBelowCenter(for: avatar.width)
        let block: CGRect = anchors.loginBlock ?? avatar
        let buttonSize: CGSize = .init(width: 420, height: 56)
        // Under the hint line even while it is empty: "Touch ID or Enter Password" may show up later.
        let below: CGFloat = min(anchors.hintBottom.map { $0 - 6 } ?? block.minY - 12, wingsBottom - 10)
        let buttonOrigin: CGFloat = if below - buttonSize.height >= screen.frame.minY + 4 {
            below - buttonSize.height
        } else {
            min(block.minY, wingsBottom) - buttonSize.height
        }
        let buttonFrame: CGRect = .init(x: avatar.midX - buttonSize.width / 2, y: buttonOrigin, width: buttonSize.width, height: buttonSize.height)
        let panel: OverlayPanel = .init(contentRect: buttonFrame, interactive: true)
        panel.show(content, aboveLockScreen: true)
        promptPanel = panel
    }

    /// The window of the wings, its ring centered on `avatar`.
    private static func wingsFrame(around avatar: CGRect) -> CGRect {
        let side: CGFloat = LockScreenWings.side(for: avatar.width)
        // Whole points: a half point would be rounded by the window server, shifting the ring.
        return .init(
            x: (avatar.midX - side / 2).rounded(),
            y: (avatar.midY - side / 2).rounded(),
            width: side,
            height: side
        )
    }

    // MARK: - Animations

    /// Decodes the wallpapers ahead of time so the next animation starts instantly.
    func prepareWallpaper() {
        Task {
            for screen in NSScreen.screens {
                _ = await wallpaper(for: screen)
            }
        }
    }

    /// Plays the locking animation on every display, then calls `lock`.
    /// - Parameter title: Shown under the Locky logo.
    func lock(animated: Bool, title: String, lock: @escaping @MainActor () -> Void) {
        guard animated, !NSScreen.screens.isEmpty else {
            lock()
            return
        }
        lockTask = Task {
            // Above the lock screen: once the session is locked, the logo fades into it instead of
            // being cut off.
            let panels: [OverlayPanel] = await showTransition(.locking, title: title, aboveLockScreen: true)
            try? await Task.sleep(for: .seconds(Self.lockDuration))
            lock()
            // The lock screen is put in front as it appears: bring the animation back above it until
            // it is shown, then fade into it.
            for delay in [0, 80, 200, 400] {
                try? await Task.sleep(for: .milliseconds(delay == 0 ? 0 : delay / 2))
                panels.forEach { LockScreenSpace.shared.adopt($0) }
            }
            try? await Task.sleep(for: .milliseconds(400))
            await fadeOut(panels, duration: 0.9)
            closeTransition(panels)
        }
    }

    /// Covers the lock screen while Locky types the password; removed by ``finishUnlock()``.
    func beginUnlock(animated: Bool, title: String) {
        hidePrompt()
        guard animated else { return }
        Task {
            // Decode first: unlocked meanwhile, there is nothing to cover anymore.
            for screen in NSScreen.screens {
                _ = await wallpaper(for: screen)
            }
            guard SessionLocker.isScreenLocked else { return }
            let panels: [OverlayPanel] = await showTransition(.unlocking, title: title, aboveLockScreen: true)
            // Safety net: never leave the lock screen covered if the unlock fails.
            try? await Task.sleep(for: .seconds(6))
            closeTransition(panels)
        }
    }

    /// Fades every panel out together (Core Animation, see ``OverlayPanel/fadeOut(duration:)``).
    private func fadeOut(_ panels: [OverlayPanel], duration: TimeInterval) async {
        await withTaskGroup(of: Void.self) { group in
            for panel in panels {
                group.addTask { await panel.fadeOut(duration: duration) }
            }
        }
    }

    /// The session is unlocked: fade the overlays out.
    func finishUnlock() {
        hidePrompt()
        let panels: [OverlayPanel] = transitionPanels
        guard !panels.isEmpty else { return }
        Task {
            await fadeOut(panels, duration: 0.4)
            closeTransition(panels)
        }
    }

    /// Preview: plays the locking then the unlocking animation without locking the Mac.
    func playPreview(title: String) {
        guard transitionPanels.isEmpty else { return }
        Task {
            let lockPanels: [OverlayPanel] = await showTransition(.locking, title: title, aboveLockScreen: false)
            // Where the real lock screen would appear.
            try? await Task.sleep(for: .seconds(Self.lockDuration + 0.8))
            closeTransition(lockPanels)
            _ = await showTransition(.unlocking, title: title, aboveLockScreen: false)
            try? await Task.sleep(for: .seconds(Self.unlockDuration))
            finishUnlock()
        }
    }

    /// One overlay per display, each with its own wallpaper, all started together.
    private func showTransition(_ kind: TransitionView.Kind, title: String, aboveLockScreen: Bool) async -> [OverlayPanel] {
        var desktops: [(screen: NSScreen, image: NSImage?)] = []
        for screen in NSScreen.screens {
            desktops.append((screen, await wallpaper(for: screen)))
        }
        closeTransition()
        let panels: [OverlayPanel] = desktops.map { screen, image in
            let panel: OverlayPanel = .init(contentRect: screen.frame, interactive: false)
            panel.show(
                TransitionView(kind: kind, desktop: image, title: title, logoSize: Self.logoSize(on: screen)),
                aboveLockScreen: aboveLockScreen
            )
            return panel
        }
        transitionPanels = panels
        return panels
    }

    /// The logo takes about a quarter of the height of the screen.
    private static func logoSize(on screen: NSScreen) -> CGFloat {
        min(max(screen.frame.height * 0.24, 160), 320)
    }

    private func wallpaper(for screen: NSScreen) async -> NSImage? {
        let display: CGDirectDisplayID = screen.displayID
        let signature: String = MacImageRenderer.wallpaperSignature(for: screen)
        if let cached = wallpaperCache[display], cached.signature == signature {
            return cached.image
        }
        guard let image = await MacImageRenderer.screenWallpaper(for: screen) else { return nil }
        // Size zero: the image keeps its own aspect ratio, the view fills the screen with it.
        let wallpaper: NSImage = .init(cgImage: image, size: .zero)
        wallpaperCache[display] = (signature, wallpaper)
        return wallpaper
    }

    /// Closes `panels` if they are still the current transition (or the current one when `nil`).
    private func closeTransition(_ panels: [OverlayPanel]? = nil) {
        guard !transitionPanels.isEmpty else { return }
        if let panels, panels.first !== transitionPanels.first { return }
        transitionPanels.forEach { $0.orderOut(nil) }
        transitionPanels = []
    }
}

extension NSScreen {
    /// Identifier of the display, stable while it stays connected.
    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}
