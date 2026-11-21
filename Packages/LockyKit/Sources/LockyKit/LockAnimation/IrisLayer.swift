import SwiftUI

/// The wallpaper seen through an iris that closes on the ring of the Locky logo, with a thin
/// glowing edge. Animatable, so the diameter shrinks at a constant visual pace (logarithmic
/// interpolation) instead of rushing at the end.
struct IrisLayer: View, @MainActor Animatable {
    let image: PlatformImage?
    let size: CGSize
    let center: CGPoint
    /// Diameter of the ring of the logo.
    let ringDiameter: CGFloat
    /// 0: open on the whole screen, 1: closed on the ring.
    var iris: Double
    /// The bubble left in the ring: 1 shown, 0 swallowed.
    var bubble: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { .init(iris, bubble) }
        set {
            iris = newValue.first
            bubble = newValue.second
        }
    }

    var body: some View {
        ZStack {
            if let image {
                Image(platformImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    // Drawn into the ring: slight zoom and blur as the iris closes.
                    .scaleEffect(1 + 0.18 * iris, anchor: anchor)
                    .blur(radius: 8 * iris)
                    .clipped()
                    .mask {
                        Circle()
                            .frame(width: diameter, height: diameter)
                            .position(center)
                    }
            }
            Circle()
                .strokeBorder(.white, lineWidth: 2)
                .frame(width: diameter, height: diameter)
                .shadow(color: .white.opacity(0.8), radius: 10)
                .opacity(min(1, iris * 1.6) * bubble)
                .position(center)
        }
        .frame(width: size.width, height: size.height)
    }

    private var anchor: UnitPoint {
        guard size.width > 0, size.height > 0 else { return .center }
        return .init(x: center.x / size.width, y: center.y / size.height)
    }

    /// Covers the whole screen when open; shrinks geometrically down to the ring.
    private var diameter: CGFloat {
        let open: CGFloat = 2 * hypot(max(center.x, size.width - center.x), max(center.y, size.height - center.y)) + 40
        guard open > 0, ringDiameter > 0 else { return 0 }
        return open * pow(ringDiameter / open, iris) * bubble
    }
}
