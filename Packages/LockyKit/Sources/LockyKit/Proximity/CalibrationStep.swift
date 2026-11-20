import Foundation

/// The two places where the signal is measured: the user puts the iPhone flat about 1 m from the
/// Mac, confirms, then steps back to 2 m and confirms again.
public enum CalibrationStep: String, Codable, Sendable, CaseIterable {
    case near
    case far

    /// Distance of the iPhone from the Mac, in meters.
    public var distance: Double {
        switch self {
        case .near: DistanceModel.calibrationDistance
        case .far: DistanceModel.farCalibrationDistance
        }
    }

    /// How long the Mac listens: the median of about twenty readings.
    public static let measureDuration: Duration = .seconds(6)
}
