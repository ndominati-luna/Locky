import SwiftUI

/// Main interface once paired: the Mac in full screen, the other screens behind two buttons. On
/// the large screen of an unfolded iPhone Duo, two pages instead (see ``UnfoldedMainView``).
struct MainView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.screenFold) private var fold

    var body: some View {
        @Bindable var model = model
        Group {
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
        .sheet(isPresented: $model.isAboutPresented) {
            AboutView()
        }
    }
}

/// The buttons of the main screen, each in its own glass: About on the leading side, the break-in
/// reports (a red dot while some are unseen) and the settings on the trailing side.
struct MainToolbar: ToolbarContent {
    @Environment(AppModel.self) private var model

    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("About Locky", systemImage: "info") {
                model.isAboutPresented = true
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
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
        }
        ToolbarSpacer(.fixed, placement: .topBarTrailing)
        ToolbarItem(placement: .topBarTrailing) {
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
