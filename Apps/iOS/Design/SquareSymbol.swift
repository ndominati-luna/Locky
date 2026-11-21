import SwiftUI

/// A symbol fitted in a square image. The glass of a toolbar button hugs its icon, and the Mac
/// symbols are much wider than tall: squared, the glass stays a circle like its neighbors (the
/// toolbar ignores frames set on the icon).
@MainActor
enum SquareSymbol {
    private static var cache: [String: Image] = [:]

    static func image(_ name: String, side: CGFloat = 26, scale: CGFloat) -> Image {
        let key: String = "\(name)@\(side)x\(scale)"
        if let image = cache[key] {
            return image
        }
        let renderer: ImageRenderer = .init(
            content: Image(systemName: name)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
        )
        renderer.scale = scale
        guard let uiImage = renderer.uiImage else {
            return Image(systemName: name)
        }
        let image: Image = .init(uiImage: uiImage).renderingMode(.template)
        cache[key] = image
        return image
    }
}
