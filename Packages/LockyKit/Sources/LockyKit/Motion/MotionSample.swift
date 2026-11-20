import Foundation

/// One device motion reading (user acceleration in g, rotation rate in rad/s).
public struct MotionSample: Codable, Sendable, Equatable {
    public var acceleration: SIMD3<Double>
    public var rotation: SIMD3<Double>

    public init(acceleration: SIMD3<Double>, rotation: SIMD3<Double>) {
        self.acceleration = acceleration
        self.rotation = rotation
    }
}
