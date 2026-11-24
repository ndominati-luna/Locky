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
    /// The radius of its corners in plan.
    static let cornerRadius: CGFloat = 0.95

    var body: some View {
        Canvas { context, size in
            let across: CGFloat = size.width / Self.width
            let down: CGFloat = size.height / Self.depth
            let rim: CGFloat = 0.12
            let corner: CGSize = .init(width: Self.cornerRadius * across, height: Self.cornerRadius * down)
            context.fill(Path(roundedRect: CGRect(origin: .zero, size: size), cornerSize: corner), with: .color(aluminium))
            let glass: CGRect = CGRect(origin: .zero, size: size).insetBy(dx: rim * across, dy: rim * down)
            context.fill(
                Path(
                    roundedRect: glass,
                    cornerSize: CGSize(width: (Self.cornerRadius - rim) * across, height: (Self.cornerRadius - rim) * down)
                ),
                with: .linearGradient(
                    Gradient(colors: [Color(white: 0.985), Color(white: 0.93)]),
                    startPoint: CGPoint(x: glass.minX, y: glass.minY),
                    endPoint: CGPoint(x: glass.maxX, y: glass.maxY)
                )
            )
        }
    }
}
