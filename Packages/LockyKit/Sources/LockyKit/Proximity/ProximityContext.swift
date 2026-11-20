import Foundation

/// Everything besides the signal that influences locking decisions.
public struct ProximityContext: Sendable, Equatable {
    /// The Mac session is locked.
    public var isLocked: Bool
    /// The iPhone reports it is moving. A still iPhone never triggers a lock.
    public var isMoving: Bool
    /// Mouse, trackpad or keyboard were used in the last seconds.
    public var isComputerInUse: Bool
    /// The iPhone is in a phone call: the lock distance is doubled.
    public var isOnCall: Bool

    public init(isLocked: Bool, isMoving: Bool, isComputerInUse: Bool, isOnCall: Bool) {
        self.isLocked = isLocked
        self.isMoving = isMoving
        self.isComputerInUse = isComputerInUse
        self.isOnCall = isOnCall
    }
}
