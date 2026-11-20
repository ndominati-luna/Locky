import Foundation

/// The distance scale of Locky, from the Mac to "infinity", shared by the gauge of the iPhone and
/// the track of the Mac so the iPhone and the padlock sit at the very same place on both.
///
/// Logarithmic over ``DistanceModel/lockDistanceRange``, like the original Locky scale: short
/// distances, where the lock distance usually is, get most of the room.
public enum DistanceScale {
    public static let range: ClosedRange<Double> = DistanceModel.lockDistanceRange

    /// Where `distance` sits on the scale, from 0 (the Mac) to 1 (the far end).
    public static func ratio(for distance: Double) -> Double {
        let clamped: Double = min(max(distance, range.lowerBound), range.upperBound)
        return log(clamped / range.lowerBound) / log(range.upperBound / range.lowerBound)
    }

    /// The distance at `ratio` (0 to 1) of the scale.
    public static func distance(at ratio: Double) -> Double {
        let clamped: Double = min(max(ratio, 0), 1)
        return range.lowerBound * pow(range.upperBound / range.lowerBound, clamped)
    }
}
