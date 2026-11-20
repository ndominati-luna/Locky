import Foundation
import Observation
import Sparkle

/// Sparkle 2 automatic updates (the Mac app is distributed outside the Mac App Store).
@MainActor
@Observable
final class UpdaterController {
    @ObservationIgnored private let controller: SPUStandardUpdaterController?
    private(set) var canCheckForUpdates: Bool = false
    @ObservationIgnored private var observation: NSKeyValueObservation?

    init() {
        // Without an EdDSA public key Sparkle refuses to start: keep the menu item disabled until the
        // appcast is set up (SUPublicEDKey in Info.plist).
        let publicKey: String = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        guard !publicKey.isEmpty else {
            controller = nil
            return
        }
        let controller: SPUStandardUpdaterController = .init(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
        self.controller = controller
        canCheckForUpdates = controller.updater.canCheckForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.new]) { [weak self] _, change in
            let canCheck: Bool = change.newValue ?? false
            Task { @MainActor in self?.canCheckForUpdates = canCheck }
        }
    }

    var isConfigured: Bool {
        controller != nil
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }
}
