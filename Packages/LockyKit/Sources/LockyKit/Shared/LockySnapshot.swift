import Foundation

/// State shared with widgets, controls and the Apple Watch.
public struct LockySnapshot: Codable, Sendable, Equatable {
    public var isPaired: Bool
    public var macName: String?
    public var family: MacFamily
    /// `true` while the iPhone and the Mac are connected over Bluetooth.
    public var isConnected: Bool
    public var lockState: LockState
    public var lockStateDate: Date?
    /// `false` when automatic locking is paused on the Mac.
    public var isAutoLockEnabled: Bool
    /// When `true`, only the Apple Watch may unlock the Mac.
    public var unlockOnlyFromWatch: Bool
    /// Distance at which the Mac locks, in meters (`nil` when unknown).
    public var lockDistance: Double?
    public var updatedAt: Date

    public init(
        isPaired: Bool,
        macName: String?,
        family: MacFamily,
        isConnected: Bool,
        lockState: LockState,
        lockStateDate: Date?,
        isAutoLockEnabled: Bool,
        unlockOnlyFromWatch: Bool,
        lockDistance: Double? = nil,
        updatedAt: Date
    ) {
        self.isPaired = isPaired
        self.macName = macName
        self.family = family
        self.isConnected = isConnected
        self.lockState = lockState
        self.lockStateDate = lockStateDate
        self.isAutoLockEnabled = isAutoLockEnabled
        self.unlockOnlyFromWatch = unlockOnlyFromWatch
        self.lockDistance = lockDistance
        self.updatedAt = updatedAt
    }

    /// Snapshot of a device that has never been paired.
    public static let unpaired: LockySnapshot = .init(
        isPaired: false,
        macName: nil,
        family: .macBook,
        isConnected: false,
        lockState: .unknown,
        lockStateDate: nil,
        isAutoLockEnabled: true,
        unlockOnlyFromWatch: false,
        updatedAt: .distantPast
    )

    /// Snapshot used by previews and widget placeholders.
    public static let preview: LockySnapshot = .init(
        isPaired: true,
        macName: "MacBook Pro",
        family: .macBook,
        isConnected: true,
        lockState: .unlocked,
        lockStateDate: .now.addingTimeInterval(-600),
        isAutoLockEnabled: true,
        unlockOnlyFromWatch: false,
        lockDistance: 1.5,
        updatedAt: .now
    )

    /// Localized one line status, e.g. "Locked", "Out of reach" (the wording of the other widgets
    /// and of the Live Activity).
    public var localizedStatus: String {
        guard isPaired else { return String(localized: "Not paired", bundle: .module) }
        guard isConnected else { return String(localized: "Out of reach", bundle: .module) }
        guard isAutoLockEnabled else { return String(localized: "Autolock disabled", bundle: .module) }
        return lockState.localizedName
    }

    /// `true` when a lock/unlock command can currently reach the Mac.
    public var canSendCommands: Bool {
        isPaired && isConnected
    }
}
