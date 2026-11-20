import SwiftUI

/// Full screen photographic background, the signature of Locky since 2015: the Mac wallpaper when
/// known (blurred and saturated like the original), the deep blue ocean otherwise.
///
/// A veil keeps text readable: dark in Dark Mode, frosted white in Light Mode. Faded (almost
/// gray) while the Mac is out of reach.
struct ImmersiveBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    var wallpaper: Data?
    /// Strength of the veil, from 0 (raw photo) to 1 (text heavy screens).
    var intensity: Double = 0.4
    var isFaded: Bool = false

    var body: some View {
        // The photo is an overlay of a flexible color so its aspect ratio never widens the layout.
        Color(colorScheme == .dark ? .black : .white)
            .overlay {
                Group {
                    if let image = wallpaper.flatMap(UIImage.init(data:)) {
                        Image(uiImage: image)
                            .resizable()
                    } else {
                        Image(.oceanBackground)
                            .resizable()
                    }
                }
                .scaledToFill()
                .blur(radius: 28, opaque: true)
                .saturation(isFaded ? 0.2 : 1.6)
                .scaleEffect(1.15)
                .transition(.opacity)
            }
            .overlay {
                veil
            }
            .clipped()
            .ignoresSafeArea()
            .animation(.smooth(duration: 0.6), value: isFaded)
            .accessibilityHidden(true)
    }

    private var veil: LinearGradient {
        if colorScheme == .dark {
            LinearGradient(
                colors: [.black.opacity(intensity * 0.4), .black.opacity(intensity), .black.opacity(min(1, intensity * 1.8))],
                startPoint: .top,
                endPoint: .bottom
            )
        } else {
            LinearGradient(
                colors: [.white.opacity(0.35 + intensity * 0.4), .white.opacity(0.45 + intensity * 0.45), .white.opacity(0.55 + intensity * 0.45)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
