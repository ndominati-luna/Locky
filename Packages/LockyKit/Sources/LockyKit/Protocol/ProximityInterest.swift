import Foundation

/// How closely the iPhone follows the distance to the Mac (``LockyMessage/proximityInterest(_:)``),
/// so that the Mac sends it no more often than it is shown: every reading wakes the iPhone.
public enum ProximityInterest: String, Codable, Sendable {
    /// Locky is on screen: its gauge follows the distance closely.
    case live
    /// Only the Live Activity shows it, which is not redrawn more often than every few seconds.
    case glance
    /// Nothing shows it: Locky is in the background without a Live Activity.
    case none

    /// The shortest delay between two readings sent, `nil` for none at all.
    public var interval: Duration? {
        switch self {
        case .live: .milliseconds(500)
        case .glance: .seconds(5)
        case .none: nil
        }
    }
}
