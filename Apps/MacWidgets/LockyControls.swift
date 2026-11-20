import AppIntents
import LockyKit
import SwiftUI
import WidgetKit

/// "Locky activated" switch for Control Center and the menu bar.
struct LockyActivatedControl: ControlWidget {
    static let kind: String = "studio.lunabee.locky.mac.control.activated"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: LockyActivatedValueProvider()) { isOn in
            ControlWidgetToggle("Locky", isOn: isOn, action: SetLockyActivatedIntent()) { isOn in
                Label(isOn ? "Activated" : "Paused", systemImage: isOn ? "lock.shield.fill" : "lock.shield")
            }
        }
        .displayName("Locky activated")
        .description("Turns locking your Mac when your iPhone walks away on or off.")
    }
}

/// Current "Locky activated" state shared by the Mac app.
struct LockyActivatedValueProvider: ControlValueProvider {
    var previewValue: Bool { true }

    func currentValue() async throws -> Bool {
        MacSharedStore.state().isAutoLockEnabled
    }
}

/// One click "Lock Mac" control.
struct LockMacNowControl: ControlWidget {
    static let kind: String = "studio.lunabee.locky.mac.control.lock"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LockMacNowIntent()) {
                Label("Lock Mac", systemImage: "lock.laptopcomputer")
            }
        }
        .displayName("Lock Mac")
        .description("Locks your Mac immediately.")
    }
}
