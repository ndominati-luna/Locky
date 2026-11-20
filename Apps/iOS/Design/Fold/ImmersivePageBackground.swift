import SwiftUI

extension View {
    /// The immersive wallpaper background of the paired screens. On the large screen of a
    /// foldable, both pages share a single background set by ``MainView``, so pages add none.
    func immersivePageBackground(wallpaper: Data? = nil, intensity: Double) -> some View {
        modifier(ImmersivePageBackground(wallpaper: wallpaper, intensity: intensity))
    }
}

private struct ImmersivePageBackground: ViewModifier {
    @Environment(\.screenFold) private var fold
    let wallpaper: Data?
    let intensity: Double

    func body(content: Content) -> some View {
        if fold == nil {
            content.background(ImmersiveBackground(wallpaper: wallpaper, intensity: intensity))
        } else {
            // Let the shared wallpaper show through the navigation stack of the page.
            content.containerBackground(.clear, for: .navigation)
        }
    }
}
