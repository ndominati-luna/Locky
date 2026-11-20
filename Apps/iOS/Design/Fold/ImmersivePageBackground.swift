import SwiftUI

extension View {
    /// The immersive wallpaper background of the paired screens. On the large screen of a
    /// foldable, both pages share a single background set by ``MainView``, so pages add none.
    /// - Parameter isFaded: Almost gray, like the main screen while the Mac is out of reach.
    func immersivePageBackground(wallpaper: Data? = nil, intensity: Double, isFaded: Bool = false) -> some View {
        modifier(ImmersivePageBackground(wallpaper: wallpaper, intensity: intensity, isFaded: isFaded))
    }
}

private struct ImmersivePageBackground: ViewModifier {
    @Environment(\.screenFold) private var fold
    let wallpaper: Data?
    let intensity: Double
    let isFaded: Bool

    func body(content: Content) -> some View {
        if fold == nil {
            content.background(ImmersiveBackground(wallpaper: wallpaper, intensity: intensity, isFaded: isFaded))
        } else {
            // Let the shared wallpaper show through the navigation stack of the page.
            content.containerBackground(.clear, for: .navigation)
        }
    }
}
