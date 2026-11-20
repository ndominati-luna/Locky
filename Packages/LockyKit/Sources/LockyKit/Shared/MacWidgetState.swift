import Foundation

/// State the Mac app shares with its desktop widget and its controls.
public struct MacWidgetState: Codable, Sendable, Equatable {
    public var isPaired: Bool
    public var phoneName: String?
    public var isConnected: Bool
    /// Estimated distance of the iPhone in meters, rounded to limit widget reloads.
    public var distance: Double?
    public var lockDistance: Double
    public var batteryLevel: Int?
    /// "Locky activated": automatic locking when the iPhone walks away.
    public var isAutoLockEnabled: Bool
    public var updatedAt: Date

    public init(
        isPaired: Bool,
        phoneName: String?,
        isConnected: Bool,
        distance: Double?,
        lockDistance: Double,
        batteryLevel: Int?,
        isAutoLockEnabled: Bool,
        updatedAt: Date
    ) {
        self.isPaired = isPaired
        self.phoneName = phoneName
        self.isConnected = isConnected
        self.distance = distance
        self.lockDistance = lockDistance
        self.batteryLevel = batteryLevel
        self.isAutoLockEnabled = isAutoLockEnabled
        self.updatedAt = updatedAt
    }

    public static let unpaired: MacWidgetState = .init(
        isPaired: false,
        phoneName: nil,
        isConnected: false,
        distance: nil,
        lockDistance: DistanceModel.defaultLockDistance,
        batteryLevel: nil,
        isAutoLockEnabled: true,
        updatedAt: .distantPast
    )

    public static let preview: MacWidgetState = .init(
        isPaired: true,
        phoneName: "iPhone",
        isConnected: true,
        distance: 1.5,
        lockDistance: 3,
        batteryLevel: 78,
        isAutoLockEnabled: true,
        updatedAt: .now
    )
}
