import Foundation

/// Lock state of the paired Mac session.
public enum LockState: String, Codable, Sendable, CaseIterable {
    case locked
    case unlocked
    case unknown

    /// Localized, user facing description of the state.
    public var localizedName: String {
        switch self {
        case .locked:
            String(localized: "Locked", bundle: .module)
        case .unlocked:
            String(localized: "Unlocked", bundle: .module)
        case .unknown:
            String(localized: "Unknown", bundle: .module)
        }
    }

    /// SF Symbol representing the state.
    public var systemImage: String {
        switch self {
        case .locked: "lock.fill"
        case .unlocked: "lock.open.fill"
        case .unknown: "lock.trianglebadge.exclamationmark"
        }
    }
}
