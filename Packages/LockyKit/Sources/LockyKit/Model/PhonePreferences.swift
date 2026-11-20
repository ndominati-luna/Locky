import Foundation

/// Preferences chosen on the iPhone that drive the behavior of the Mac.
public struct PhonePreferences: Codable, Sendable, Equatable {
    /// Unlock the Mac as soon as the iPhone comes back in range.
    public var unlockAutomatically: Bool
    /// Take a photo of people trying to unlock the Mac while the iPhone is away.
    public var intrusionDetection: Bool
    /// Only the Apple Watch is allowed to unlock the Mac.
    public var unlockOnlyFromWatch: Bool
    /// Distance in meters beyond which the Mac locks itself.
    public var lockDistance: Double

    public init(
        unlockAutomatically: Bool = false,
        intrusionDetection: Bool = false,
        unlockOnlyFromWatch: Bool = false,
        lockDistance: Double = DistanceModel.defaultLockDistance
    ) {
        self.unlockAutomatically = unlockAutomatically
        self.intrusionDetection = intrusionDetection
        self.unlockOnlyFromWatch = unlockOnlyFromWatch
        self.lockDistance = lockDistance
    }
}
