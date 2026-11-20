import SwiftUI

/// Main interface on the large screen of an iPhone Duo held like a book, or half open like a
/// laptop: the Mac on the first page (the very screen of the iPhone), on the second what happens
/// on the Mac (music, processor, memory…) in glass cards. Settings and break-in reports open on
/// the second page too. One wallpaper spans both pages; a hairline on the fold sets them apart.
struct UnfoldedMainView: View {
    @Environment(AppModel.self) private var model
    let fold: ScreenFold

    private let gutter: CGFloat = 24

    var body: some View {
        @Bindable var model = model
        // "Your Mac" starts right on the fold, where the divider marks its edge.
        TwoPageLayout(fold: fold, gutter: gutter, secondPageStartsAtFold: true) {
            HomeView()
            NavigationStack(path: $model.path) {
                MacDashboardView()
                    .navigationDestination(for: AppRoute.self) { route in
                        AppRouteDestination(route: route)
                    }
            }
            .overlay(alignment: fold.orientation == .vertical ? .leading : .top) {
                PageDivider(orientation: fold.orientation)
            }
        }
        .background {
            ImmersiveBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.4, isFaded: !model.isConnected)
                .animation(.smooth(duration: 0.6), value: model.visuals.backgroundWallpaper)
        }
    }
}
