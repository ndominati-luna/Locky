import Foundation

/// What the proximity engine suggests doing with the Mac.
public enum ProximityDecision: Sendable, Equatable {
    case stay
    case lock
    case unlock
}
