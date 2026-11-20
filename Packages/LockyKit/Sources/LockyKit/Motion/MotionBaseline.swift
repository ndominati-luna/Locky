import Foundation

/// Noise level of the iPhone motion sensors while it lies still, measured during calibration.
public struct MotionBaseline: Codable, Sendable, Equatable {
    /// Largest absolute user acceleration per axis while still.
    public var acceleration: SIMD3<Double>
    /// Largest absolute rotation rate per axis while still.
    public var rotation: SIMD3<Double>

    /// Margin added to the baseline before a reading counts as a movement.
    public static let accelerationMargin: Double = 0.1
    /// Margin added to the baseline before a reading counts as a movement.
    public static let rotationMargin: Double = 0.1
    /// Without movement for this long, the iPhone is considered still again.
    public static let stillnessDelay: Duration = .seconds(3)
    /// Duration of the calibration measurement.
    public static let calibrationDuration: Duration = .seconds(3)

    /// Baseline used before any calibration.
    public static let zero: MotionBaseline = .init(acceleration: .zero, rotation: .zero)

    public init(acceleration: SIMD3<Double>, rotation: SIMD3<Double>) {
        self.acceleration = acceleration
        self.rotation = rotation
    }

    /// Builds a baseline from the samples captured while the iPhone was still.
    public static func measure(_ samples: [MotionSample]) -> MotionBaseline {
        samples.reduce(.zero) { baseline, sample in
            .init(
                acceleration: pointwiseMax(baseline.acceleration, abs(sample.acceleration)),
                rotation: pointwiseMax(baseline.rotation, abs(sample.rotation))
            )
        }
    }

    /// `true` when the sample exceeds the baseline on any axis.
    public func isMovement(_ sample: MotionSample) -> Bool {
        let accelerationLimit: SIMD3<Double> = acceleration + Self.accelerationMargin
        let rotationLimit: SIMD3<Double> = rotation + Self.rotationMargin
        return any(abs(sample.acceleration) .> accelerationLimit) || any(abs(sample.rotation) .> rotationLimit)
    }
}

private func abs(_ vector: SIMD3<Double>) -> SIMD3<Double> {
    .init(Swift.abs(vector.x), Swift.abs(vector.y), Swift.abs(vector.z))
}
