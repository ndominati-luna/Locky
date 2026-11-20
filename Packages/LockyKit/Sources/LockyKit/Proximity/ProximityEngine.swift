import Foundation

/// Turns raw RSSI readings into lock and unlock decisions.
///
/// - The signal is smoothed with ``RSSIFilter``.
/// - It is converted to meters with ``DistanceModel`` and compared to the lock distance.
/// - Unlocking requires coming back clearly closer (hysteresis) to avoid flapping.
/// - A decision only fires once its condition held continuously for a short dwell time.
public struct ProximityEngine: Sendable {
    /// How long the iPhone must stay beyond the lock distance before locking.
    public static let lockDwell: TimeInterval = 1.5
    /// How long the iPhone must stay within the unlock distance before unlocking.
    public static let unlockDwell: TimeInterval = 1.5
    /// Unlock distance as a fraction of the lock distance.
    public static let unlockDistanceRatio: Double = 0.7
    /// Lock distance multiplier during phone calls.
    public static let callDistanceFactor: Double = 2
    /// Upper bound of the effective lock distance.
    public static let maximumLockDistance: Double = 10

    public var model: DistanceModel
    /// Lock distance in meters.
    public var lockDistance: Double
    public private(set) var filter: RSSIFilter = .init()
    private var pending: (decision: ProximityDecision, since: Date)?

    public init(model: DistanceModel, lockDistance: Double = DistanceModel.defaultLockDistance) {
        self.model = model
        self.lockDistance = lockDistance
    }

    /// Ingests a raw RSSI reading.
    /// - Returns: The filtered reading and the decision to apply (``ProximityDecision/stay`` most of the time).
    public mutating func ingest(
        rssi: Double,
        at date: Date = .now,
        context: ProximityContext
    ) -> (reading: ProximityReading?, decision: ProximityDecision) {
        guard let filtered = filter.add(rssi, isMoving: context.isMoving, at: date) else { return (nil, .stay) }
        let reading: ProximityReading = .init(rssi: filtered, distance: model.distance(forRSSI: filtered))
        let candidate: ProximityDecision = evaluate(reading, context: context)
        guard candidate != .stay else {
            pending = nil
            return (reading, .stay)
        }
        guard let pending, pending.decision == candidate else {
            pending = (candidate, date)
            return (reading, .stay)
        }
        let dwell: TimeInterval = candidate == .lock ? Self.lockDwell : Self.unlockDwell
        guard date.timeIntervalSince(pending.since) >= dwell else { return (reading, .stay) }
        self.pending = nil
        return (reading, candidate)
    }

    /// Instant decision for a reading, without dwell time.
    public func evaluate(_ reading: ProximityReading, context: ProximityContext) -> ProximityDecision {
        let effectiveLockDistance: Double = min(
            lockDistance * (context.isOnCall ? Self.callDistanceFactor : 1),
            Self.maximumLockDistance
        )
        if context.isLocked {
            return reading.distance <= lockDistance * Self.unlockDistanceRatio ? .unlock : .stay
        }
        guard reading.distance > effectiveLockDistance, context.isMoving, !context.isComputerInUse else {
            return .stay
        }
        return .lock
    }

    /// Forgets the signal history (e.g. after a reconnection).
    public mutating func reset() {
        filter.reset()
        pending = nil
    }
}
