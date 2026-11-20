import LockyKit
import SwiftUI

/// Colors of the round Locky button of the app.
enum LockyTint {
    /// Flat red of the original Lock button.
    static let lock: Color = .init(red: 1.0, green: 0.36, blue: 0.32)
    /// Flat blue of the original Unlock button.
    static let unlock: Color = .init(red: 0.11, green: 0.57, blue: 0.96)
    /// Locky blue, when the state is not known.
    static let locky: Color = .init(red: 0.12, green: 0.55, blue: 1.0)

    static func color(for lockState: LockState) -> Color {
        switch lockState {
        case .locked: unlock
        case .unlocked: lock
        case .unknown: locky
        }
    }
}
