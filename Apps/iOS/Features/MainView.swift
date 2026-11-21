import SwiftUI

/// Main interface once paired: the Mac in full screen, the other screens behind two buttons. On
/// the large screen of an unfolded iPhone Duo, two pages instead (see ``UnfoldedMainView``).
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.screenFold) private var fold

    var body: some View {
        @Bindable var model = model
        if let fold {
            UnfoldedMainView(fold: fold)
        } else {
            NavigationStack(path: $model.path) {
                HomeView()
                    .navigationDestination(for: AppRoute.self) { route in
                        AppRouteDestination(route: route)
                    }
            }
        }
    }
}

/// The buttons of the main screen, side by side in one glass capsule: the break-in reports (a red
/// dot while some are unseen) and the settings.
struct MainToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                model.path.append(.intrusions)
            } label: {
                Label(intrusionsTitle, systemImage: "person.crop.badge.magnifyingglass")
                    .overlay(alignment: .topTrailing) {
                        if model.intrusions.unseenCount > 0 {
                            Circle()
                                .fill(.red)
                                .frame(width: 9, height: 9)
                                .offset(x: 5, y: -5)
                        }
                    }
            }
            Button("Settings", systemImage: "gearshape") {
                model.path.append(.settings)
            }
        }
    }

    private var intrusionsTitle: String {
        let count: Int = model.intrusions.unseenCount
        let title: String = .init(localized: "Break-in reports")
        return count > 0 ? "\(title) (\(count))" : title
    }
}
