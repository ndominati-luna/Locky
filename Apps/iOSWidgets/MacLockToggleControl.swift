import AppIntents
import LockyKit
import SwiftUI
import WidgetKit

/// Control Center / Lock Screen / Action button toggle: on = Mac locked.
struct MacLockToggleControl: ControlWidget {
    static let kind: String = "studio.lunabee.locky.control.toggle"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind, provider: MacLockValueProvider()) { isLocked in
            ControlWidgetToggle("Mac", isOn: isLocked, action: SetMacLockedIntent()) { isOn in
                Label(isOn ? "Locked" : "Unlocked", systemImage: isOn ? "lock.fill" : "lock.open.fill")
            }
            .tint(.accentColor)
        }
        .displayName("Lock or unlock Mac")
        .description("Shows whether your Mac is locked and toggles it.")
    }
}

/// Current lock state shared by the app.
struct MacLockValueProvider: ControlValueProvider {
    var previewValue: Bool { false }

    func currentValue() async throws -> Bool {
        SharedStore.snapshot().lockState == .locked
    }
}

/// One tap "Lock my Mac" control (handy on the Action button).
struct LockMacControl: ControlWidget {
    static let kind: String = "studio.lunabee.locky.control.lock"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: LockMacIntent()) {
                Label("Lock Mac", systemImage: "lock.laptopcomputer")
            }
        }
        .displayName("Lock Mac")
        .description("Locks your Mac immediately.")
    }
}
