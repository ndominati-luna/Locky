import SwiftUI

/// The Locky wings on the lock screen, as in the original Locky: a white ring around the user
/// picture, wings on each side. The curls of the logo would not match the ring at this size: the
/// feathers are cut along an arc concentric with it, and beat around its center.
struct LockScreenWings: View {
    let avatarDiameter: CGFloat
    /// Drawn in the ring when Locky could not find the picture of macOS.
    var picture: NSImage?
    let state: LockScreenPromptState
    @State private var spread: Double = 0
    @State private var flap: Double = 0

    /// Space between the picture and the ring.
    static let ringGap: CGFloat = 5
    static let ringWidth: CGFloat = 3
    /// Space between the ring and the feathers.
    static let featherGap: CGFloat = 5

    /// Side of the square wings image.
    static func wingScale(for avatarDiameter: CGFloat) -> CGFloat {
        avatarDiameter * 2.95
    }

    /// Side of the square view, centered on the picture: an even number of points, so that the
    /// window starts on a whole point and the ring lands exactly on the pixels of the picture.
    static func side(for avatarDiameter: CGFloat) -> CGFloat {
        let side: CGFloat = 2 * (1 - LockyWing.curlCenter.y) * wingScale(for: avatarDiameter) + 16
        return (side / 2).rounded(.up) * 2
    }

    /// How far the wings go under the center of the picture.
    static func depthBelowCenter(for avatarDiameter: CGFloat) -> CGFloat {
        max(ringRadius(for: avatarDiameter), (LockyWing.featherBottom - LockyWing.curlCenter.y) * wingScale(for: avatarDiameter))
    }

    private static func ringRadius(for avatarDiameter: CGFloat) -> CGFloat {
        avatarDiameter / 2 + ringGap + ringWidth
    }

    var body: some View {
        let side: CGFloat = Self.side(for: avatarDiameter)
        let scale: CGFloat = Self.wingScale(for: avatarDiameter)
        let center: CGPoint = .init(x: side / 2, y: side / 2)
        let ringRadius: CGFloat = Self.ringRadius(for: avatarDiameter)
        let cutRadius: CGFloat = ringRadius + Self.featherGap
        ZStack {
            if let picture {
                Image(nsImage: picture)
                    .resizable()
                    .scaledToFill()
                    .frame(width: avatarDiameter, height: avatarDiameter)
                    .clipShape(.circle)
                    .position(center)
            }
            Circle()
                .strokeBorder(.white, lineWidth: Self.ringWidth)
                .frame(width: 2 * ringRadius, height: 2 * ringRadius)
                .scaleEffect(0.88 + 0.12 * spread)
                .position(center)
            // The curls of the logo are centered on the picture, the feathers stop on an arc
            // concentric with the ring.
            ZStack {
                LockyWing(side: .left, flap: raise, pivot: LockyWing.curlCenter)
                LockyWing(side: .right, flap: raise, pivot: LockyWing.curlCenter)
            }
            .frame(width: scale, height: scale)
            .position(x: center.x, y: center.y + (0.5 - LockyWing.curlCenter.y) * scale)
            .frame(width: side, height: side)
            .mask {
                Path { path in
                    path.addRect(CGRect(x: 0, y: 0, width: side, height: side))
                    path.addEllipse(in: CGRect(x: center.x - cutRadius, y: center.y - cutRadius, width: 2 * cutRadius, height: 2 * cutRadius))
                }
                .fill(style: FillStyle(eoFill: true))
            }
        }
        .frame(width: side, height: side)
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.4), radius: 6, y: 1)
        .opacity(min(1, spread * 2))
        .onAppear {
            withAnimation(.spring(duration: 0.8, bounce: 0.35)) {
                spread = 1
            }
            withAnimation(.easeInOut(duration: 0.25).delay(0.65)) {
                flap = -12
            }
            withAnimation(.spring(duration: 0.6, bounce: 0.5).delay(0.9)) {
                flap = 0
            }
        }
        .onChange(of: state.isDismissed) { _, isDismissed in
            guard isDismissed else { return }
            // The wings fold up around the picture as they fade out, quickly: the lock screen is
            // already leaving.
            withAnimation(.easeIn(duration: 0.25)) {
                spread = 0
            }
        }
        .accessibilityHidden(true)
    }

    /// Folded wings point up; they spread then beat once.
    private var raise: Angle {
        .degrees((1 - spread) * 62 + flap)
    }
}
