import Foundation

/// Screens of the navigation stack: from the main screen, and below them.
enum AppRoute: Hashable {
    case intrusions
    /// One break-in report, by its identifier (the report is read from the store).
    case intrusion(id: String)
    case settings
}
