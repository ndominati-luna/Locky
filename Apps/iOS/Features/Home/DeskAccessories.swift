import SwiftUI

/// The Magic Keyboard and the Magic Trackpad on the desk in front of a Mac, side by side and
/// centred under it, as the camera of its picture sees them: their top laid down in perspective,
/// their front edge standing under it. The keyboard is Apple's picture of it, in the colour of the
/// Mac; it widens into the one with the numeric keypad, or narrows back, as two fingers spread it
/// or close it. Laid out at the origin of the space the camera measures.
struct DeskAccessories: View, Animatable {
    let camera: DeskCamera
    /// How far in front of the device their back edges lie, in centimetres.
    let back: CGFloat
    let keyboard: DeskKeyboard
    /// The colour of the keyboard, as in ``DeskKeyboard/colours``.
    let colour: String
    /// The aluminium of the Mac, for the edges and the rim of the trackpad.
    let aluminium: Color
    /// The width the keyboard shows: its own, or between the two while the fingers spread it or
    /// it settles.
    var keyboardWidth: CGFloat

    nonisolated var animatableData: CGFloat {
        get { keyboardWidth }
        set { keyboardWidth = newValue }
    }

    /// Between the keyboard and the trackpad.
    private static let gap: CGFloat = 3

    /// The lowest point they reach, in centimetres in front of the device, to make room for them.
    static func front(back: CGFloat) -> CGFloat {
        back + max(DeskKeyboard.depth, MagicTrackpad.depth)
    }

    /// Where the left edge of the keyboard is, in centimetres right of the middle.
    private static func keyboardLeft(width: CGFloat) -> CGFloat {
        -(width + gap + MagicTrackpad.width) / 2
    }

    /// Where the keyboard shows, for the fingers that come down on it.
    static func keyboardFrame(camera: DeskCamera, back: CGFloat, width: CGFloat) -> CGRect {
        let left: CGFloat = keyboardLeft(width: width)
        let far: CGPoint = camera.point(x: left, height: DeskKeyboard.backHeight, depth: back)
        let near: CGPoint = camera.point(x: left + width, height: 0, depth: back + DeskKeyboard.depth)
        // At the front, it is widest.
        let nearLeft: CGPoint = camera.point(x: left, height: 0, depth: back + DeskKeyboard.depth)
        return .init(x: min(far.x, nearLeft.x), y: far.y, width: near.x - min(far.x, nearLeft.x), height: near.y - far.y)
    }

    /// Where the trackpad shows, beside a keyboard `keyboardWidth` wide, for the finger that comes
    /// down on it.
    static func trackpadFrame(camera: DeskCamera, back: CGFloat, keyboardWidth: CGFloat) -> CGRect {
        let left: CGFloat = keyboardLeft(width: keyboardWidth) + keyboardWidth + gap
        let far: CGPoint = camera.point(x: left, height: MagicTrackpad.backHeight, depth: back)
        let nearLeft: CGPoint = camera.point(x: left, height: 0, depth: back + MagicTrackpad.depth)
        let near: CGPoint = camera.point(x: left + MagicTrackpad.width, height: 0, depth: back + MagicTrackpad.depth)
        return .init(x: min(far.x, nearLeft.x), y: far.y, width: near.x - min(far.x, nearLeft.x), height: near.y - far.y)
    }

    var body: some View {
        let left: CGFloat = Self.keyboardLeft(width: keyboardWidth)
        ZStack(alignment: .topLeading) {
            DeskItem(
                camera: camera,
                left: left,
                width: keyboardWidth,
                back: back,
                depth: DeskKeyboard.depth,
                backHeight: DeskKeyboard.backHeight,
                frontHeight: DeskKeyboard.frontHeight,
                cornerRadius: DeskKeyboard.cornerRadius,
                edge: aluminium
            ) {
                Image(keyboard.image(colour: colour))
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
            }
            DeskItem(
                camera: camera,
                left: left + keyboardWidth + Self.gap,
                width: MagicTrackpad.width,
                back: back,
                depth: MagicTrackpad.depth,
                backHeight: MagicTrackpad.backHeight,
                frontHeight: MagicTrackpad.frontHeight,
                cornerRadius: MagicTrackpad.cornerRadius,
                edge: aluminium
            ) {
                MagicTrackpad(aluminium: aluminium)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Something flat on the desk: its top, drawn from above, laid down by the camera, and its sides
/// down to the desk, in shade under it: its rounded outline in plan, raised from the desk to its
/// top, so that its front face rounds off at its corners into its sides, as the top does.
private struct DeskItem<Top: View>: View {
    let camera: DeskCamera
    let left: CGFloat
    let width: CGFloat
    let back: CGFloat
    let depth: CGFloat
    let backHeight: CGFloat
    let frontHeight: CGFloat
    /// The radius of its corners in plan, in centimetres, as its top shows them.
    let cornerRadius: CGFloat
    /// The colour of its edge.
    let edge: Color
    @ViewBuilder let top: Top

    var body: some View {
        let front: CGFloat = back + depth
        let farLeft: CGPoint = camera.point(x: left, height: backHeight, depth: back)
        let farRight: CGPoint = camera.point(x: left + width, height: backHeight, depth: back)
        let nearLeft: CGPoint = camera.point(x: left, height: frontHeight, depth: front)
        // Drawn about as large as it shows, a little deeper, for it to stay sharp once laid down.
        let size: CGSize = .init(width: max(farRight.x - farLeft.x, 1), height: max(nearLeft.y - farLeft.y, 2))
        let solid: Path = silhouette()
        // A canvas clips what it draws to its frame: this one has its own, around the solid, which
        // may reach beyond the space the camera measures (the trackpad, at the front, comes out of
        // the width of an iMac).
        let bounds: CGRect = solid.boundingRect.insetBy(dx: -1, dy: -1)
        ZStack(alignment: .topLeading) {
            // The space the camera measures, as large as it is offered.
            Color.clear
            top
                .frame(width: size.width, height: size.height)
                // Drawn first at that size, with a careful filter, then laid down.
                .drawingGroup()
                .projectionEffect(
                    camera.surface(
                        size: size,
                        left: left,
                        width: width,
                        back: back,
                        depth: depth,
                        backHeight: backHeight,
                        frontHeight: frontHeight
                    )
                )
        }
        .background(alignment: .topLeading) {
            Canvas { context, _ in
                context.translateBy(x: -bounds.minX, y: -bounds.minY)
                let topY: CGFloat = camera.point(x: left + width / 2, height: frontHeight, depth: front).y
                let floorY: CGFloat = camera.point(x: left + width / 2, height: 0, depth: front).y
                let shade: GraphicsContext.Shading = .linearGradient(
                    Gradient(colors: [edge.mix(with: .black, by: 0.12), edge.mix(with: .black, by: 0.3)]),
                    startPoint: CGPoint(x: 0, y: topY),
                    endPoint: CGPoint(x: 0, y: max(floorY, topY + 1))
                )
                context.fill(solid, with: shade)
            }
            .frame(width: max(bounds.width, 1), height: max(bounds.height, 1))
            .offset(x: bounds.minX, y: bounds.minY)
        }
    }

    /// All of it as the camera sees it, its top and its sides: its rounded outline in plan, raised
    /// from the desk to its top (which slopes from its back to its front). A solid without a hollow,
    /// whose picture is the hull of the pictures of its outline on the desk and at its top. In one
    /// piece, under its top, which hides all but its front, its corners and the side it turns to
    /// the camera: drawn wall by wall, the edges of the walls and of the top would each half cover
    /// the pixels they share, and let the desk show through between them.
    private func silhouette() -> Path {
        let radius: CGFloat = min(cornerRadius, width / 2, depth / 2)
        let right: CGFloat = left + width
        let front: CGFloat = back + depth
        // The outline in plan, across from the middle and in front of the device.
        var outline: [(x: CGFloat, depth: CGFloat)] = []
        let steps: Int = 10
        let corners: [(centre: (x: CGFloat, depth: CGFloat), start: Double)] = [
            ((left + radius, back + radius), .pi),
            ((right - radius, back + radius), 1.5 * .pi),
            ((right - radius, front - radius), 0),
            ((left + radius, front - radius), 0.5 * .pi)
        ]
        for corner in corners {
            for step in 0...steps {
                let angle: Double = corner.start + Double(step) / Double(steps) * .pi / 2
                outline.append(
                    (corner.centre.x + radius * CGFloat(cos(angle)), corner.centre.depth + radius * CGFloat(sin(angle)))
                )
            }
        }
        /// The height of its top above a point `along` its depth.
        func topHeight(_ along: CGFloat) -> CGFloat {
            backHeight + (frontHeight - backHeight) * (along - back) / max(depth, 0.01)
        }
        let points: [CGPoint] = outline.flatMap { point in
            [
                camera.point(x: point.x, height: 0, depth: point.depth),
                camera.point(x: point.x, height: topHeight(point.depth), depth: point.depth)
            ]
        }
        var path: Path = .init()
        path.addLines(Self.hull(of: points))
        path.closeSubpath()
        return path
    }

    /// The convex hull of `points`, around them in order (Andrew's monotone chain).
    private static func hull(of points: [CGPoint]) -> [CGPoint] {
        let sorted: [CGPoint] = points.sorted { $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x }
        guard sorted.count > 2 else { return sorted }
        /// Whether going from `start` to `middle` then to `end` turns one way (and not straight on).
        func turns(_ start: CGPoint, _ middle: CGPoint, _ end: CGPoint) -> Bool {
            (middle.x - start.x) * (end.y - start.y) - (middle.y - start.y) * (end.x - start.x) > 0
        }
        var lower: [CGPoint] = []
        for point in sorted {
            while lower.count >= 2, !turns(lower[lower.count - 2], lower[lower.count - 1], point) {
                lower.removeLast()
            }
            lower.append(point)
        }
        var upper: [CGPoint] = []
        for point in sorted.reversed() {
            while upper.count >= 2, !turns(upper[upper.count - 2], upper[upper.count - 1], point) {
                upper.removeLast()
            }
            upper.append(point)
        }
        return Array(lower.dropLast()) + Array(upper.dropLast())
    }
}
