import Foundation
import ServiceManagement

/// Starts Locky at login (replaces the former "lockyhelper" login item app).
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // The user may have to approve it in System Settings > General > Login Items.
            SMAppService.openSystemSettingsLoginItems()
        }
    }
}
