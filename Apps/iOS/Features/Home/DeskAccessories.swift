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
                edge: aluminium
            ) {
                MagicTrackpad(aluminium: aluminium)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Something flat on the desk: its top, drawn from above, laid down by the camera, and its front
/// edge in shade under it.
private struct DeskItem<Top: View>: View {
    let camera: DeskCamera
    let left: CGFloat
    let width: CGFloat
    let back: CGFloat
    let depth: CGFloat
    let backHeight: CGFloat
    let frontHeight: CGFloat
    /// The colour of its edge.
    let edge: Color
    @ViewBuilder let top: Top

    var body: some View {
        let front: CGFloat = back + depth
        let farLeft: CGPoint = camera.point(x: left, height: backHeight, depth: back)
        let farRight: CGPoint = camera.point(x: left + width, height: backHeight, depth: back)
        let nearLeft: CGPoint = camera.point(x: left, height: frontHeight, depth: front)
        let floor: CGPoint = camera.point(x: left + width, height: 0, depth: front)
        // Drawn as large as it shows, so that laying it down neither shrinks nor stretches it much:
        // the graphics card filters a picture it shrinks poorly (the gaps between the keys
        // shimmered and doubled).
        let size: CGSize = .init(width: max(farRight.x - farLeft.x, 1), height: max(nearLeft.y - farLeft.y, 2))
        ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(bottomLeadingRadius: (floor.y - nearLeft.y) * 0.6, bottomTrailingRadius: (floor.y - nearLeft.y) * 0.6)
                .fill(
                    LinearGradient(
                        colors: [edge.mix(with: .black, by: 0.12), edge.mix(with: .black, by: 0.3)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: max(floor.x - nearLeft.x, 1), height: max(floor.y - nearLeft.y, 0.5))
                .offset(x: nearLeft.x, y: nearLeft.y)
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
    }
}
