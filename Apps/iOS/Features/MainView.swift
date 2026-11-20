import SwiftUI

/// Main interface once paired: the Mac in full screen, other screens behind the "•••" menu. On
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
                        switch route {
                        case .intrusions: IntrusionsView()
                        case .settings: SettingsView()
                        }
                    }
            }
        }
    }
}

/// The "•••" button of the main screen.
struct MainMenu: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Menu {
            Button {
                model.path.append(.intrusions)
            } label: {
                Label(intrusionsTitle, systemImage: "person.crop.badge.magnifyingglass")
            }
            Button {
                model.path.append(.settings)
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
        } label: {
            Label("More", systemImage: "ellipsis")
                .labelStyle(.iconOnly)
                .overlay(alignment: .topTrailing) {
                    if model.intrusions.unseenCount > 0 {
                        Circle()
                            .fill(.red)
                            .frame(width: 9, height: 9)
                            .offset(x: 5, y: -5)
                    }
                }
        }
        .accessibilityLabel(Text("More"))
    }

    private var intrusionsTitle: String {
        let count: Int = model.intrusions.unseenCount
        let title: String = .init(localized: "Break-in reports")
        return count > 0 ? "\(title) (\(count))" : title
    }
}
