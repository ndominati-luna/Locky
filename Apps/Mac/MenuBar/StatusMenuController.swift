import AppKit
import Observation
import SwiftUI

/// The native status bar menu of Locky, like the original app: a custom view at the top (paired
/// iPhone and "Locky activated" switch), then regular menu items and an Options submenu.
@MainActor
final class StatusMenuController: NSObject {
    private let model: MacAppModel
    private let windows: WindowManager
    private let statusItem: NSStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu: NSMenu = .init()

    init(model: MacAppModel, windows: WindowManager) {
        self.model = model
        self.windows = windows
        super.init()
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
        statusItem.button?.toolTip = "Locky"
        observeConnection()
    }

    // MARK: - Icon

    private func observeConnection() {
        let isConnected: Bool = withObservationTracking {
            model.session.connection.isConnected
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeConnection() }
        }
        let image: NSImage = .init(resource: isConnected ? .menuBar : .menuBarDisconnected)
        image.isTemplate = true
        image.size = NSSize(width: 18, height: 18)
        statusItem.button?.image = image
    }

    // MARK: - Menu

    private func rebuild() {
        menu.removeAllItems()
        if model.isPaired {
            let header: NSMenuItem = .init()
            let hostingView: NSHostingView = .init(rootView: StatusMenuHeader().environment(model))
            hostingView.frame.size = hostingView.fittingSize
            header.view = hostingView
            menu.addItem(header)
            menu.addItem(.separator())
            addWarnings()
            menu.addItem(ClosureMenuItem(String(localized: "Lock now"), image: "lock.fill") { [weak self] in
                self?.model.lockNow()
            })
            menu.addItem(.separator())
            menu.addItem(optionsItem())
        } else {
            menu.addItem(ClosureMenuItem(String(localized: "Connect to an iPhone"), image: "iphone.radiowaves.left.and.right") { [weak self] in
                self?.windows.show(.pairing)
            })
            addWarnings()
        }
        #if DEBUG
        if MacDemo.isEnabled {
            menu.addItem(.separator())
            menu.addItem(ClosureMenuItem("Démo : animation de verrouillage", image: "play.circle") { [weak self] in
                self?.model.previewLockAnimation()
            })
        }
        #endif
        menu.addItem(.separator())
        if model.updater.isConfigured {
            let updates: ClosureMenuItem = .init(String(localized: "Check for updates…"), image: "arrow.down.circle") { [weak self] in
                self?.model.updater.checkForUpdates()
            }
            updates.isEnabled = model.updater.canCheckForUpdates
            menu.addItem(updates)
        }
        menu.addItem(ClosureMenuItem(String(localized: "Release notes…"), image: "doc.text") { [weak self] in
            self?.windows.show(.releaseNotes)
        })
        menu.addItem(ClosureMenuItem(String(localized: "Contact support"), image: "envelope") { [weak self] in
            guard let self else { return }
            NSWorkspace.shared.open(MacSupportMail.url(model: self.model))
        })
        menu.addItem(ClosureMenuItem(String(localized: "About Locky"), image: "info.circle") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(String(localized: "Quit Locky"), keyEquivalent: "q") {
            NSApp.terminate(nil)
        })
    }

    private func addWarnings() {
        if model.session.connection == .bluetoothOff {
            menu.addItem(ClosureMenuItem(String(localized: "Turn on Bluetooth"), image: "exclamationmark.triangle.fill") {
                BluetoothPower.turnOn()
            })
        }
        if model.isPaired, !model.isAccessibilityGranted {
            menu.addItem(ClosureMenuItem(String(localized: "Allow Locky to type your password…"), image: "exclamationmark.triangle.fill") { [weak self] in
                self?.model.requestAccessibility()
            })
        }
        if isCameraMissing {
            menu.addItem(ClosureMenuItem(String(localized: "Allow the camera for intruder photos…"), image: "camera.fill") { [weak self] in
                self?.model.allowCamera()
            })
        }
        if isWallpaperMissing {
            menu.addItem(ClosureMenuItem(String(localized: "Show my wallpaper on my iPhone…"), image: "photo") { [weak self] in
                self?.model.requestWallpaperAccess()
            })
        }
        if model.session.connection == .bluetoothOff || (model.isPaired && !model.isAccessibilityGranted) || isCameraMissing
            || isWallpaperMissing {
            menu.addItem(.separator())
        }
    }

    /// The wallpaper is in a protected folder Locky was not allowed to read (or did not ask for).
    private var isWallpaperMissing: Bool {
        guard model.isPaired, !model.isSetupPending else { return false }
        return model.wallpaperAccess == .notAsked || model.wallpaperAccess == .denied
    }

    /// Intruder detection is on but Locky may not use the camera (yet).
    private var isCameraMissing: Bool {
        guard model.isPaired, model.preferences.phonePreferences.intrusionDetection else { return false }
        return model.cameraAccess == .denied || model.cameraAccess == .notDetermined
    }

    private func optionsItem() -> NSMenuItem {
        let options: NSMenu = .init()
        options.autoenablesItems = false
        let preferences: MacPreferences = model.preferences
        options.addItem(ClosureMenuItem(
            String(localized: "“Unlock with Locky” on the lock screen"),
            state: preferences.isLockScreenOverlayEnabled ? .on : .off
        ) {
            preferences.isLockScreenOverlayEnabled.toggle()
        })
        options.addItem(ClosureMenuItem(
            String(localized: "Open at login"),
            state: model.isLaunchAtLoginEnabled ? .on : .off
        ) { [weak self] in
            guard let self else { return }
            self.model.setLaunchAtLogin(!self.model.isLaunchAtLoginEnabled)
        })
        options.addItem(.separator())
        // The animation in a section of its own: its style (none included), text and background.
        options.addItem(ClosureMenuItem(String(localized: "Customize the animation…"), image: "sparkles") { [weak self] in
            self?.windows.show(.animation)
        })
        options.addItem(.separator())
        options.addItem(ClosureMenuItem(String(localized: "Update session password…"), image: "key") { [weak self] in
            self?.windows.show(.password)
        })
        options.addItem(ClosureMenuItem(String(localized: "Unpair \(model.phoneName)…"), image: "iphone.slash") { [weak self] in
            self?.confirmUnpair()
        })
        let item: NSMenuItem = .init(title: String(localized: "Options"), action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        item.submenu = options
        return item
    }

    private func confirmUnpair() {
        NSApp.activate()
        let alert: NSAlert = .init()
        alert.messageText = String(localized: "Unpair \(model.phoneName)?")
        alert.informativeText = String(localized: "Locky will stop locking and unlocking this Mac.")
        alert.addButton(withTitle: String(localized: "Unpair"))
        alert.addButton(withTitle: String(localized: "Cancel"))
        alert.buttons.first?.hasDestructiveAction = true
        if alert.runModal() == .alertFirstButtonReturn {
            model.unpair()
        }
    }
}

extension StatusMenuController: NSMenuDelegate {
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu == self.menu else { return }
        model.refreshCameraAccess()
        rebuild()
    }
}
