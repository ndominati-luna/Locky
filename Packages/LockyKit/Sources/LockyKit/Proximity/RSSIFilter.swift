import Foundation

/// One dimensional Kalman filter tuned for Bluetooth RSSI.
///
/// Compared to the former moving average it reacts faster when the iPhone moves (the process
/// noise grows with motion) and stays stable when it lies still. While still, sudden drops are
/// most often a hand or a body between the devices, so they are heavily down-weighted instead of
/// being ignored outright.
public struct RSSIFilter: Sendable, Equatable {
    /// Variance growth per second of the true signal while the iPhone is still (dB²/s).
    public static let stillProcessNoise: Double = 0.4
    /// Variance growth per second of the true signal while the iPhone moves (dB²/s).
    public static let movingProcessNoise: Double = 12
    /// Variance of one RSSI reading (dB²), roughly a 4 dB standard deviation.
    public static let measurementNoise: Double = 16
    /// Weight penalty applied to drops while the iPhone is still.
    public static let stillDropPenalty: Double = 12

    /// Filtered RSSI, `nil` before the first reading.
    public private(set) var estimate: Double?
    /// Variance of ``estimate`` (dB²).
    public private(set) var variance: Double = 0
    private var lastDate: Date?

    public init() {}

    /// Adds a raw reading and returns the filtered value.
    @discardableResult
    public mutating func add(_ rssi: Double, isMoving: Bool, at date: Date = .now) -> Double? {
        // CoreBluetooth reports 127 when the value is unavailable; valid readings are negative.
        guard rssi < 0, rssi > -127 else { return estimate }
        guard let current = estimate, let lastDate else {
            estimate = rssi
            variance = Self.measurementNoise
            self.lastDate = date
            return estimate
        }
        let elapsed: Double = max(0, date.timeIntervalSince(lastDate))
        self.lastDate = date
        variance += (isMoving ? Self.movingProcessNoise : Self.stillProcessNoise) * elapsed

        var noise: Double = Self.measurementNoise
        let innovation: Double = rssi - current
        if !isMoving, innovation < -2 * (variance + noise).squareRoot() {
            noise *= Self.stillDropPenalty
        }
        let gain: Double = variance / (variance + noise)
        estimate = current + gain * innovation
        variance *= 1 - gain
        return estimate
    }

    /// Forgets every reading.
    public mutating func reset() {
        estimate = nil
        variance = 0
        lastDate = nil
    }
}
