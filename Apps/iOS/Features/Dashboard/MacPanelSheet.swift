import SwiftUI

/// The page of the Mac in a sheet, from the button of ``MainToolbar``: its own navigation, so
/// that the break-in reports open inside it.
struct MacPanelSheet: View {
    @State private var path: [AppRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            MacDashboardView(isModal: true)
                .navigationDestination(for: AppRoute.self) { route in
                    AppRouteDestination(route: route)
                }
        }
        .presentationDragIndicator(.visible)
    }
}
