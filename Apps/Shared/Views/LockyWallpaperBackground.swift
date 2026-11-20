import SwiftUI

/// The blurred wallpaper of the Mac, like the main screen of the app (Locky blue without it),
/// faded while the Mac is out of reach.
struct LockyWallpaperBackground: View {
    let wallpaper: Data?
    var blur: CGFloat = 18
    var isFaded: Bool = false

    var body: some View {
        ZStack {
            if let image = wallpaper.flatMap(UIImage.init(data:)) {
                Color.black
                    .overlay {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: blur, opaque: true)
                            .saturation(1.5)
                    }
                    .clipped()
                LinearGradient(colors: [.black.opacity(0.1), .black.opacity(0.5)], startPoint: .top, endPoint: .bottom)
            } else {
                LinearGradient(
                    colors: [Color(red: 0.11, green: 0.84, blue: 1.0), Color(red: 0.12, green: 0.38, blue: 0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
            if isFaded {
                Color.black.opacity(0.3)
            }
        }
        .saturation(isFaded ? 0.15 : 1)
    }
}
