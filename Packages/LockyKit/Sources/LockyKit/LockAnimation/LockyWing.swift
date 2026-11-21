import SwiftUI

/// One wing of the Locky logo, cut from the vector wings, rotating around the curl that holds the
/// padlock (or the user picture on the lock screen).
public struct LockyWing: View {
    public enum Side: Sendable {
        case left
        case right
    }

    /// Center of the circle drawn by the curls of the wings, in the square wings image.
    public static let curlCenter: UnitPoint = .init(x: 0.5, y: 0.455)
    /// Radius of that circle, as a fraction of the side of the image.
    public static let curlRadius: CGFloat = 0.095
    /// Lowest feather, from the top, as a fraction of the side of the image.
    public static let featherBottom: CGFloat = 0.59

    let side: Side
    /// Raises the wing (positive) around its curl.
    var flap: Angle = .zero
    /// Point the wing turns around; the inner point of its curl by default.
    var pivot: UnitPoint?

    public init(side: Side, flap: Angle = .zero, pivot: UnitPoint? = nil) {
        self.side = side
        self.flap = flap
        self.pivot = pivot
    }

    public var body: some View {
        Image("LockyWings", bundle: .module)
            .resizable()
            .scaledToFit()
            // Keeps one half of the image: one wing.
            .mask {
                HStack(spacing: 0) {
                    side == .left ? Color.black : Color.clear
                    side == .left ? Color.clear : Color.black
                }
            }
            .rotationEffect(side == .left ? flap : -flap, anchor: pivot ?? curlPivot)
            .accessibilityHidden(true)
    }

    /// The inner point of the curl.
    private var curlPivot: UnitPoint {
        let x: CGFloat = side == .left ? Self.curlCenter.x - Self.curlRadius : Self.curlCenter.x + Self.curlRadius
        return .init(x: x, y: Self.curlCenter.y)
    }
}
