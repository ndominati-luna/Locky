import Foundation

/// How a Pro Display XDR stands on its Pro Stand: turned landscape or portrait, slid up or down its
/// arm, tilted, and turned on the desk. Stored as a short string, for `@AppStorage`.
struct ProDisplayXDRPose: Equatable, RawRepresentable {
    /// Where it rests, in degrees clockwise: 0 landscape, -90 or 90 portrait.
    var rotation: Double = 0
    /// Along the travel of the stand: 0 at the bottom, 1 at the top.
    var height: Double = 0.35
    /// Degrees: positive leans the top back, negative forward (the Pro Stand allows -5° to 25°).
    var tilt: Double = 0
    /// Degrees the panel is swiveled on its stand, positive to the right.
    var swivel: Double = 0

    static let tiltRange: ClosedRange<Double> = -5...25
    static let swivelRange: ClosedRange<Double> = -35...35

    var isPortrait: Bool {
        abs(rotation) > 45
    }

    init() {}

    init?(rawValue: String) {
        let values: [Double] = rawValue.split(separator: " ").compactMap { Double($0) }
        guard values.count == 4 else { return nil }
        rotation = values[0]
        height = values[1]
        tilt = values[2]
        swivel = values[3]
    }

    var rawValue: String {
        [rotation, height, tilt, swivel].map { String($0) }.joined(separator: " ")
    }
}
