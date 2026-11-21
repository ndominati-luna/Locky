import AppKit
import SwiftUI

/// The windows of Locky for Mac (pairing assistant, password update), created on demand.
///
/// Locky is a menu bar app with a native status menu (AppKit), so its windows are AppKit windows
/// hosting SwiftUI views.
@MainActor
final class WindowManager: NSObject {
    enum Kind {
        case pairing
        case password
        case animation
        case releaseNotes
    }

    private let model: MacAppModel
    private var windows: [Kind: NSWindow] = [:]

    init(model: MacAppModel) {
        self.model = model
        super.init()
    }

    func show(_ kind: Kind) {
        if let window = windows[kind] {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let close: CloseWindowAction = .init { [weak self] in self?.close(kind) }
        let controller: NSViewController
        let window: NSWindow
        switch kind {
        case .pairing:
            controller = NSHostingController(
                rootView: PairingWindowView()
                    .environment(model)
                    .environment(\.closeWindow, close)
            )
            window = .init(contentViewController: controller)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isMovableByWindowBackground = true
            window.title = "Locky"
        case .password:
            controller = NSHostingController(
                rootView: UpdatePasswordView()
                    .environment(model)
                    .environment(\.closeWindow, close)
            )
            window = .init(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = String(localized: "Update session password")
        case .animation:
            controller = NSHostingController(
                rootView: AnimationSettingsView()
                    .environment(model)
                    .environment(\.closeWindow, close)
            )
            window = .init(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = String(localized: "Lock animation")
        case .releaseNotes:
            controller = NSHostingController(
                rootView: ReleaseNotesView()
                    .environment(\.closeWindow, close)
            )
            window = .init(contentViewController: controller)
            window.styleMask = [.titled, .closable]
            window.title = String(localized: "Release notes")
        }
        window.isReleasedWhenClosed = false
        window.delegate = self
        // Always in front, on every Space, even while System Settings is open for a permission:
        // the setup must stay in sight until it is done.
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hidesOnDeactivate = false
        window.center()
        windows[kind] = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func close(_ kind: Kind) {
        windows[kind]?.close()
    }
}

extension WindowManager: NSWindowDelegate {
    /// The setup window stays open until the mandatory first try succeeded.
    nonisolated func windowShouldClose(_ sender: NSWindow) -> Bool {
        MainActor.assumeIsolated {
            guard windows[.pairing] == sender, model.isSetupPending else { return true }
            NSSound.beep()
            return false
        }
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        let closing: NSWindow? = notification.object as? NSWindow
        MainActor.assumeIsolated {
            guard let closing else { return }
            for (kind, window) in windows where window == closing {
                windows[kind] = nil
                if kind == .pairing {
                    model.setupWindowDidClose()
                }
            }
        }
    }
}
