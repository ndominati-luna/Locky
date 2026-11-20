import Foundation

/// Output of ``ProximityEngine`` for one RSSI reading.
public struct ProximityReading: Sendable, Equatable, Codable {
    /// Filtered RSSI (dBm).
    public var rssi: Double
    /// Estimated distance (m).
    public var distance: Double

    public init(rssi: Double, distance: Double) {
        self.rssi = rssi
        self.distance = distance
    }
}
