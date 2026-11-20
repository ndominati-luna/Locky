import SwiftUI

/// The screen of a route of the navigation stack, on the main screen of the iPhone as on the
/// second page of an unfolded iPhone Duo.
struct AppRouteDestination: View {
    let route: AppRoute

    var body: some View {
        switch route {
        case .intrusions:
            IntrusionsView()
        case .intrusion(let id):
            IntrusionDetailView(reportID: id)
        case .settings:
            SettingsView()
        }
    }
}
