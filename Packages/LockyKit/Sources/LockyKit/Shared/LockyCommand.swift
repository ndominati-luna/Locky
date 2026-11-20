import Foundation

/// A command an extension (widget, control, intent) asks the iPhone app to perform.
public enum LockyCommand: String, Codable, Sendable {
    case lock
    case unlock
    /// Locks if unlocked, unlocks if locked.
    case toggle
}
