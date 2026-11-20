import Foundation

/// Battery of a MacBook.
public struct MacBattery: Codable, Sendable, Equatable {
    /// Charge, from 0 to 100.
    public var level: Int
    public var isCharging: Bool
    public var isOnPower: Bool
    /// Time left on battery, when macOS has estimated it.
    public var minutesRemaining: Int?

    public init(level: Int, isCharging: Bool, isOnPower: Bool, minutesRemaining: Int?) {
        self.level = level
        self.isCharging = isCharging
        self.isOnPower = isOnPower
        self.minutesRemaining = minutesRemaining
    }
}
