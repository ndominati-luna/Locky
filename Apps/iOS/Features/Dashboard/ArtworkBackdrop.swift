import SwiftUI

/// The artwork of the track playing, blurred and saturated like the wallpaper behind the screens,
/// as the backdrop of the music card. A veil keeps the text readable: dark in Dark Mode, frosted
/// white in Light Mode. Almost gray while the Mac is out of reach; a new artwork fades in.
struct ArtworkBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    let artwork: Data?
    let artworkID: String?
    let isFaded: Bool

    var body: some View {
        ZStack {
            if let image = artwork.flatMap(UIImage.init(data:)) {
                // The photo is an overlay of a flexible color so its aspect ratio never widens the card.
                Color.clear
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 24, opaque: true)
                            .saturation(isFaded ? 0.2 : 1.6)
                            .scaleEffect(1.15)
                    }
                    .overlay {
                        colorScheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.5)
                    }
                    .clipped()
                    .id(artworkID)
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.6), value: artwork == nil ? nil : artworkID ?? "")
        .animation(.smooth(duration: 0.6), value: isFaded)
        .accessibilityHidden(true)
    }
}
