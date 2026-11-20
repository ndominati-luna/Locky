import Foundation

/// Log-distance path loss model converting RSSI to an approximate distance in meters.
///
/// `rssi(d) = rssiAtOneMeter - 10 · n · log10(d)`. Calibrated during the pairing, or again from the
/// settings: the user puts the iPhone flat about 1 m from the Mac and confirms, then at 2 m. The
/// first point gives the reference, both give the exponent `n` of the room, so that the default
/// lock distance (1.5 m) lies between two real measures.
public struct DistanceModel: Sendable, Equatable, Codable {
    /// First calibration point ("put your iPhone about 1 m from your Mac"): the reference of the
    /// model itself, far enough from the Mac to avoid the near field, where the signal varies a lot
    /// from one position to the next.
    public static let calibrationDistance: Double = 1
    /// Second calibration point ("step back to 2 m").
    public static let farCalibrationDistance: Double = 2
    /// Exponents measured outside this range come from a disturbed measure (someone walking
    /// between the devices…): the default one is used instead.
    public static let plausiblePathLossExponents: ClosedRange<Double> = 1.5...4
    /// Calibrations of the first versions, measured with the iPhone against the Mac.
    public static let legacyCalibrationDistance: Double = 0.1
    /// Indoor path loss exponent.
    public static let defaultPathLossExponent: Double = 2.2
    /// Distance used when the user did not pick one: the threshold of the former app (about
    /// 25 dB below the calibration), which read 3 m with a 20 cm calibration distance.
    public static let defaultLockDistance: Double = 1.5
    /// Range offered by the lock distance slider.
    public static let lockDistanceRange: ClosedRange<Double> = 0.5...10

    public var rssiAtOneMeter: Double
    public var pathLossExponent: Double

    public init(rssiAtOneMeter: Double, pathLossExponent: Double = Self.defaultPathLossExponent) {
        self.rssiAtOneMeter = rssiAtOneMeter
        self.pathLossExponent = pathLossExponent
    }

    /// Builds the model from the RSSI measured at `calibrationDistance`.
    public init(
        calibrationRSSI: Double,
        calibrationDistance: Double = Self.calibrationDistance,
        pathLossExponent: Double = Self.defaultPathLossExponent
    ) {
        self.init(
            rssiAtOneMeter: calibrationRSSI + 10 * pathLossExponent * log10(calibrationDistance),
            pathLossExponent: pathLossExponent
        )
    }

    /// Builds the model from two measures: the exponent of the room when plausible.
    public init(nearRSSI: Double, nearDistance: Double, farRSSI: Double, farDistance: Double) {
        let measured: Double = (nearRSSI - farRSSI) / (10 * log10(farDistance / nearDistance))
        let exponent: Double = Self.plausiblePathLossExponents.contains(measured) ? measured : Self.defaultPathLossExponent
        self.init(calibrationRSSI: nearRSSI, calibrationDistance: nearDistance, pathLossExponent: exponent)
    }

    /// Estimated distance in meters for a RSSI.
    public func distance(forRSSI rssi: Double) -> Double {
        pow(10, (rssiAtOneMeter - rssi) / (10 * pathLossExponent))
    }

    /// Expected RSSI at a distance in meters.
    public func rssi(atDistance distance: Double) -> Double {
        rssiAtOneMeter - 10 * pathLossExponent * log10(max(distance, 0.01))
    }
}
