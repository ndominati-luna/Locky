import Foundation

/// Screens of the navigation stack: from the main screen, and below them.
enum AppRoute: Hashable {
    case intrusions
    /// One break-in report, by its identifier (the report is read from the store).
    case intrusion(id: String)
    case settings
    /// The measurements of the waves around.
    case waves
    /// One measurement, by its identifier (read from ``AppModel/waves``).
    case wave(id: UUID)

    /// The waves around, or one of their measurements.
    var isWaves: Bool {
        switch self {
        case .waves, .wave: true
        case .intrusions, .intrusion, .settings: false
        }
    }
}
