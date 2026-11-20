import Foundation
import LockyKit

/// Calibration of the distance asked from the settings: the user stands about 1 m from the Mac,
/// back to it with the iPhone in hand (between the two, as when walking away), and confirms, then
/// at 2 m; each time the Mac measures the signal for a few seconds.
enum DistanceCalibration: Equatable {
    /// Waiting for the user to put the iPhone at the distance of the step and confirm.
    case ready(CalibrationStep)
    case measuring(CalibrationStep)
    case done
    case failed

    var isMeasuring: Bool {
        if case .measuring = self { true } else { false }
    }
}
