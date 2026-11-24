import SwiftUI

/// The Magic Trackpad, drawn from above in any proportions (the camera lays it down on the desk,
/// see ``DeskAccessories``): its glass, white, in a thin rim of aluminium the colour of the Mac.
/// Real measures, in centimetres.
struct MagicTrackpad: View {
    let aluminium: Color

    static let width: CGFloat = 16
    static let depth: CGFloat = 11.49
    static let backHeight: CGFloat = 1.09
    static let frontHeight: CGFloat = 0.49

    var body: some View {
        Canvas { context, size in
            let across: CGFloat = size.width / Self.width
            let down: CGFloat = size.height / Self.depth
            let rim: CGFloat = 0.12
            context.fill(
                Path(roundedRect: CGRect(origin: .zero, size: size), cornerSize: CGSize(width: 0.95 * across, height: 0.95 * down)),
                with: .color(aluminium)
            )
            let glass: CGRect = CGRect(origin: .zero, size: size).insetBy(dx: rim * across, dy: rim * down)
            context.fill(
                Path(roundedRect: glass, cornerSize: CGSize(width: (0.95 - rim) * across, height: (0.95 - rim) * down)),
                with: .linearGradient(
                    Gradient(colors: [Color(white: 0.985), Color(white: 0.93)]),
                    startPoint: CGPoint(x: glass.minX, y: glass.minY),
                    endPoint: CGPoint(x: glass.maxX, y: glass.maxY)
                )
            )
        }
    }
}
