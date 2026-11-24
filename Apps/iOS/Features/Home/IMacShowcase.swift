import LockyKit
import SwiftUI

/// An iMac on the home screen, handled like the real one, without any button, with the Magic
/// Keyboard and the Magic Trackpad that come with it on the desk in front, in its colour. Its
/// stand only tilts: two fingers set down on the display lean it back or forward on its hinge, the foot staying
/// put, and it stays where it is let go; at either end of the hinge, a little knock. Two fingers
/// spreading on the keyboard bring the one with the numeric keypad, closing on it the compact one.
/// One finger on the trackpad shows the cursor on the screen, which follows it until it lifts.
/// Three fingers set the brightness of its screen. A double tap puts it back as it came: upright,
/// at full brightness. One finger pulls the whole Mac, the rubber band of the home screen.
/// Disabled (the Mac out of reach), it is left alone.
struct IMacShowcase: View {
    let frame: MacFrame
    let outline: IMacOutline
    var wallpaper: UIImage?
    let lockState: LockState
    var isConnected: Bool = true
    var userPicture: Data?
    var userName: String?
    var isUnlocking: Bool = false
    /// One finger: how far it pulled the Mac, then `nil` once let go.
    let pulled: (CGSize?) -> Void

    /// Degrees the display leans back from its picture: 0 upright, below 0 forward.
    @AppStorage("iMacTilt") private var storedTilt: Double = 0
    @AppStorage("iMacBrightness") private var storedBrightness: Double = 1
    /// Where the display and the brightness rest once handled: state, which animates, unlike the
    /// stored values (a double tap puts the display back smoothly).
    @State private var restingTilt: Double?
    @State private var restingBrightness: Double?
    /// The keyboard on the desk, with its numeric keypad or not, as two fingers left it.
    @AppStorage("deskKeyboard") private var storedKeyboard: DeskKeyboard = .compact
    @State private var restingKeyboard: DeskKeyboard?
    /// How many times wider the fingers spread the keyboard, while they do.
    @State private var keyboardStretch: CGFloat = 1
    /// Two fingers came down on the keyboard: theirs, the display does not move. Only two fingers
    /// set down on the display tilt it.
    @State private var isOnKeyboard: Bool = false
    @State private var isOnDisplay: Bool = false
    @State private var isTwoFingerPanning: Bool = false
    @State private var isPinching: Bool = false
    @State private var canvasWidth: CGFloat = 1
    /// One finger on the trackpad: the cursor shows and follows it, from where it was left.
    @State private var isOnTrackpad: Bool = false
    @State private var showsCursor: Bool = false
    @State private var cursor: CGPoint = .init(x: 0.5, y: 0.5)
    @State private var cursorStart: CGPoint = .init(x: 0.5, y: 0.5)

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The hands at work, on top of ``tilt`` and ``brightness``, since their gesture began.
    @State private var tilting: Double = 0
    @State private var brightening: Double = 0
    @State private var isPulling: Bool = false
    @State private var isTilting: Bool = false
    @State private var isBrightening: Bool = false
    /// More fingers came down during a gesture: it gave its place back and waits for its end.
    @State private var isPullSuspended: Bool = false
    @State private var isTiltSuspended: Bool = false
    @State private var showsBrightness: Bool = false
    @State private var brightnessFade: Task<Void, Never>?
    @State private var stop: TiltStop = .between
    @State private var haptics: HingeHaptics = .init()
    /// Where the hinge last gave a grain under the fingers.
    @State private var lastGrain: Double = 0
    /// The height of the display on screen, which the fingers travel to tilt it.
    @State private var displayHeight: CGFloat = 1

    /// Apple publishes no figure for the stand of the 24-inch iMac: a little forward, a good deal
    /// back, as it is measured in the hand.
    private static let tiltRange: ClosedRange<Double> = -5...15
    /// Degrees between two grains of the hinge under the fingers.
    private static let grainStep: Double = 1
    /// Degrees the display leans as the fingers travel its whole height.
    private static let tiltPerHeight: Double = 40

    var body: some View {
        IMacScene(
            tilt: shownTilt,
            image: frame.image,
            outline: outline,
            screenRect: frame.screen ?? .init(x: 0, y: 0, width: 1, height: 1),
            keyboard: keyboard,
            colour: DeskKeyboard.colour(ofAsset: frame.asset),
            keyboardWidth: keyboard.width(stretchedBy: keyboardStretch)
        ) {
            MacScreen(
                wallpaper: wallpaper,
                lockState: lockState,
                userPicture: userPicture,
                userName: userName,
                isUnlocking: isUnlocking
            )
            .overlay {
                Color.black
                    .opacity((1 - shownBrightness) * 0.82)
            }
            .overlay {
                if showsCursor {
                    MacCursor(position: cursor)
                        .transition(.opacity)
                }
            }
            .overlay {
                if showsBrightness {
                    BrightnessIndicator(level: shownBrightness)
                        .transition(.opacity)
                }
            }
        }
        .aspectRatio(IMacMeasures.aspectRatio(of: frame.image.size, outline: outline), contentMode: .fit)
        .saturation(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.45), value: lockState)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
            canvasWidth = max(width, 1)
            displayHeight = max(width * frame.image.size.height / max(frame.image.size.width, 1) * outline.chinBottom, 1)
        }
        .contentShape(.rect)
        .gesture(HandPanRecognizer(touches: 1, isEnabled: isEnabled, began: oneFingerBegan, changed: pull) { _ in endPull() })
        .gesture(HandPanRecognizer(touches: 2, isEnabled: isEnabled, began: twoFingersBegan, changed: tiltChanged) { _ in endTilt() })
        .gesture(HandPinchRecognizer(isEnabled: isEnabled, began: twoFingersBegan, changed: pinchChanged, ended: pinchEnded))
        .gesture(HandPanRecognizer(touches: 3, isEnabled: isEnabled, changed: brightnessChanged) { _ in endBrightness() })
        .gesture(HandDoubleTapRecognizer(isEnabled: isEnabled, tapped: reset))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "iMac"))
        .accessibilityActions {
            if isEnabled {
                Button("Tilt the display back") {
                    rest(tilt: Self.tiltRange.upperBound, animation: settling)
                }
                Button("Put the display back") {
                    reset()
                }
            }
        }
    }

    // MARK: What is shown: the resting display and brightness, plus the hands

    private var tilt: Double {
        restingTilt ?? storedTilt
    }

    private var brightness: Double {
        restingBrightness ?? storedBrightness
    }

    private var keyboard: DeskKeyboard {
        restingKeyboard ?? storedKeyboard
    }

    private var shownTilt: Double {
        min(max(tilt + tilting, Self.tiltRange.lowerBound), Self.tiltRange.upperBound)
    }

    private var shownBrightness: Double {
        min(max(brightness + brightening, 0), 1)
    }

    private var settling: Animation? {
        reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.12)
    }

    // MARK: The hands

    /// The camera that lays the keyboard and the trackpad on the desk, as the canvas is drawn.
    private var deskCamera: DeskCamera {
        IMacMeasures.deskCamera(
            width: canvasWidth,
            pictureHeight: canvasWidth * frame.image.size.height / max(frame.image.size.width, 1),
            outline: outline
        )
    }

    /// Where one finger comes down decides: the trackpad, or the whole Mac.
    private func oneFingerBegan(_ point: CGPoint) {
        let trackpad: CGRect = DeskAccessories.trackpadFrame(camera: deskCamera, back: IMacMeasures.accessoriesBack, keyboardWidth: keyboard.width)
        let margin: CGFloat = deskCamera.scale * 1.5
        isOnTrackpad = trackpad.insetBy(dx: -margin, dy: -margin).contains(point)
        guard isOnTrackpad else { return }
        cursorStart = cursor
        withAnimation(.easeOut(duration: 0.12)) { showsCursor = true }
    }

    /// The cursor moves as the finger does on the trackpad: across it, a little more than the
    /// width of the screen.
    private func moveCursor(_ translation: CGSize) {
        let trackpad: CGFloat = max(DeskAccessories.trackpadFrame(camera: deskCamera, back: IMacMeasures.accessoriesBack, keyboardWidth: keyboard.width).width, 1)
        let screen: NormalizedRect = frame.screen ?? .init(x: 0, y: 0, width: 1, height: 1)
        let aspect: CGFloat = screen.width * frame.image.size.width / max(screen.height * frame.image.size.height, 1)
        cursor = .init(
            x: min(max(cursorStart.x + translation.width / trackpad * 1.3, 0), 0.98),
            y: min(max(cursorStart.y + translation.height / trackpad * 1.3 * aspect, 0), 0.97)
        )
    }

    private func pull(_ translation: CGSize) {
        if isOnTrackpad {
            moveCursor(translation)
            return
        }
        guard !isPullSuspended, !isTilting, !isBrightening else { return }
        isPulling = true
        pulled(translation)
    }

    private func endPull() {
        if isOnTrackpad {
            isOnTrackpad = false
            withAnimation(.easeIn(duration: 0.2)) { showsCursor = false }
            return
        }
        isPullSuspended = false
        guard isPulling else { return }
        isPulling = false
        pulled(nil)
    }

    /// More fingers on the Mac: a pull in progress lets the Mac go back and waits for its end.
    private func moreFingersDown() {
        guard isPulling else { return }
        isPulling = false
        isPullSuspended = true
        pulled(nil)
    }

    /// Where two fingers come down decides: the keyboard, the display, or nothing.
    private func twoFingersBegan(_ point: CGPoint) {
        guard !isTwoFingerPanning, !isPinching else { return }
        let camera: DeskCamera = IMacMeasures.deskCamera(
            width: canvasWidth,
            pictureHeight: canvasWidth * frame.image.size.height / max(frame.image.size.width, 1),
            outline: outline
        )
        let keys: CGRect = DeskAccessories.keyboardFrame(camera: camera, back: IMacMeasures.accessoriesBack, width: keyboard.width)
        let margin: CGFloat = camera.scale * 1.5
        isOnKeyboard = keys.insetBy(dx: -margin, dy: -margin).contains(point)
        // The display and its chin, down to the foot.
        let chin: CGFloat = canvasWidth * frame.image.size.height / max(frame.image.size.width, 1) * outline.chinBottom
        isOnDisplay = !isOnKeyboard && CGRect(x: 0, y: 0, width: canvasWidth, height: chin).contains(point)
    }

    /// Every two-finger gesture is over: the next ones decide again where they are.
    private func twoFingersUp() {
        guard !isTwoFingerPanning, !isPinching else { return }
        isOnKeyboard = false
        isOnDisplay = false
    }

    private func pinchChanged(_ ratio: CGFloat) {
        isPinching = true
        guard isOnKeyboard else { return }
        moreFingersDown()
        keyboardStretch = ratio
    }

    /// Spread enough, the keyboard with the numeric keypad; closed enough, the compact one.
    private func pinchEnded(_ ratio: CGFloat) {
        isPinching = false
        if isOnKeyboard {
            let settled: DeskKeyboard = keyboard.settled(afterStretching: ratio)
            if settled != keyboard {
                haptics.knock(isDeep: settled == .compact)
            }
            withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
                restingKeyboard = settled
                keyboardStretch = 1
            }
            storedKeyboard = settled
        }
        twoFingersUp()
    }

    private func tiltChanged(_ translation: CGSize) {
        isTwoFingerPanning = true
        moreFingersDown()
        guard isOnDisplay, !isTiltSuspended, !isBrightening else { return }
        if !isTilting {
            isTilting = true
            lastGrain = shownTilt
        }
        // Up pushes the top of the display back, down pulls it forward.
        let wanted: Double = tilt - Double(translation.height / displayHeight) * Self.tiltPerHeight
        tilting = min(max(wanted, Self.tiltRange.lowerBound), Self.tiltRange.upperBound) - tilt
        // The hinge under the fingers: a knock at its ends, and a fine grain as it turns, which
        // keeps clear of the ends so that the knock comes alone.
        updateStop()
        if stop == .between, isClearOfStops, abs(shownTilt - lastGrain) >= Self.grainStep {
            lastGrain = shownTilt
            haptics.grain()
        }
    }

    /// Away from both ends of the hinge by more than half a degree.
    private var isClearOfStops: Bool {
        shownTilt > Self.tiltRange.lowerBound + 0.5 && shownTilt < Self.tiltRange.upperBound - 0.5
    }

    private func endTilt() {
        isTwoFingerPanning = false
        isTiltSuspended = false
        defer { twoFingersUp() }
        guard isTilting else { return }
        rest(tilt: shownTilt)
        tilting = 0
        isTilting = false
    }

    private func brightnessChanged(_ translation: CGSize) {
        moreFingersDown()
        if isTilting {
            // A third finger came down: the display goes back to where the two found it.
            withAnimation(settling) { tilting = 0 }
            isTilting = false
            isTiltSuspended = true
        }
        isBrightening = true
        // Up brightens, the height of the display from dark to full.
        let wanted: Double = brightness - Double(translation.height / displayHeight)
        brightening = min(max(wanted, 0), 1) - brightness
        brightnessFade?.cancel()
        if !showsBrightness {
            withAnimation(.easeOut(duration: 0.2)) { showsBrightness = true }
        }
    }

    private func endBrightness() {
        guard isBrightening else { return }
        rest(brightness: shownBrightness)
        brightening = 0
        isBrightening = false
        brightnessFade = Task {
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            withAnimation(.easeIn(duration: 0.35)) { showsBrightness = false }
        }
    }

    /// Back as it came, from wherever the display is, smoothly.
    private func reset() {
        rest(tilt: shownTilt, brightness: shownBrightness)
        tilting = 0
        brightening = 0
        isTilting = false
        isBrightening = false
        stop = .between
        rest(tilt: 0, brightness: 1, animation: settling)
    }

    /// Leaves the display or the brightness there, and keeps it for the next time.
    private func rest(tilt: Double? = nil, brightness: Double? = nil, animation: Animation? = nil) {
        withAnimation(animation) {
            if let tilt {
                restingTilt = tilt
            }
            if let brightness {
                restingBrightness = brightness
            }
        }
        if let tilt {
            storedTilt = tilt
        }
        if let brightness {
            storedBrightness = brightness
        }
    }

    /// A knock once the display reaches an end of its hinge, not again until it has left it.
    private func updateStop() {
        let shown: Double = shownTilt
        let previous: TiltStop = stop
        if shown >= Self.tiltRange.upperBound {
            stop = .back
        } else if shown <= Self.tiltRange.lowerBound {
            stop = .forward
        } else if shown < Self.tiltRange.upperBound - 1, shown > Self.tiltRange.lowerBound + 1 {
            stop = .between
        }
        guard stop != previous, stop != .between else { return }
        haptics.knock(isDeep: stop == .back)
    }
}

private enum TiltStop {
    case between
    case back
    case forward
}

/// The iMac with its display tilted by `tilt` degrees, seen through the camera of its picture, and
/// the keyboard and the trackpad on the desk in front of it. The display and its chin turn on the
/// hinge at the top of the foot; the foot stays as drawn.
private struct IMacScene<Screen: View>: View, Animatable {
    var tilt: Double
    let image: UIImage
    let outline: IMacOutline
    let screenRect: NormalizedRect
    let keyboard: DeskKeyboard
    let colour: String
    let keyboardWidth: CGFloat
    @ViewBuilder let screen: Screen

    nonisolated var animatableData: Double {
        get { tilt }
        set { tilt = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let pictureHeight: CGFloat = width * image.size.height / max(image.size.width, 1)
            let chin: CGFloat = outline.chinBottom * pictureHeight
            let camera: DeskCamera = IMacMeasures.camera(width: width, pictureHeight: pictureHeight, outline: outline)
            // The top of the foot, hidden behind the chin, which shows as the display leans back.
            let hidden: CGFloat = pictureHeight * 0.035
            ZStack(alignment: .topLeading) {
                Image(uiImage: image)
                    .resizable()
                    .frame(width: width, height: pictureHeight)
                    .offset(y: -hidden)
                    .mask(alignment: .topLeading) {
                        Rectangle()
                            .frame(width: width, height: hidden)
                            .offset(y: chin - hidden)
                    }
                Image(uiImage: image)
                    .resizable()
                    .frame(width: width, height: pictureHeight)
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: max(0, pictureHeight - chin))
                    }
                ZStack {
                    ScreenRectLayout(rect: screenRect, outset: 1) {
                        screen
                    }
                    Image(uiImage: image)
                        .resizable()
                }
                .frame(width: width, height: pictureHeight)
                .mask(alignment: .top) {
                    Rectangle()
                        .frame(height: chin)
                }
                .projectionEffect(camera.tilt(.degrees(tilt), axisHeight: IMacMeasures.hingeHeight, axisDepth: IMacMeasures.hingeDepth))
                DeskAccessories(
                    camera: IMacMeasures.deskCamera(width: width, pictureHeight: pictureHeight, outline: outline),
                    back: IMacMeasures.accessoriesBack,
                    keyboard: keyboard,
                    colour: colour,
                    aluminium: outline.aluminium,
                    keyboardWidth: keyboardWidth
                )
            }
            .frame(width: width, height: proxy.size.height, alignment: .topLeading)
        }
    }
}

/// The measures of the 24-inch iMac, in centimetres: 54.7 cm wide, its hinge at the top of the foot
/// behind the chin, about 13 cm above the desk and 2.5 cm behind the glass; and the camera of its
/// picture.
private enum IMacMeasures {
    static let width: CGFloat = 54.7
    static let hingeHeight: CGFloat = 13
    static let hingeDepth: CGFloat = 2.5
    /// The keyboard and the trackpad, in front of the foot.
    static let accessoriesBack: CGFloat = 13

    /// The camera of the picture, drawn `width` points wide and `pictureHeight` high.
    static func camera(width: CGFloat, pictureHeight: CGFloat, outline: IMacOutline) -> DeskCamera {
        .init(scale: width / Self.width, center: width / 2, desk: outline.desk * pictureHeight)
    }

    /// The camera that lays the keyboard and the trackpad on the desk: a little higher than the one
    /// of the picture, for their top to show without standing them up.
    static func deskCamera(width: CGFloat, pictureHeight: CGFloat, outline: IMacOutline) -> DeskCamera {
        var camera: DeskCamera = camera(width: width, pictureHeight: pictureHeight, outline: outline)
        camera.eyeHeight = 38
        return camera
    }

    /// The picture and, under it, room for what lies on the desk in front.
    static func aspectRatio(of size: CGSize, outline: IMacOutline) -> CGFloat {
        let camera: DeskCamera = deskCamera(width: size.width, pictureHeight: size.height, outline: outline)
        let lowest: CGFloat = camera.point(x: 0, height: 0, depth: DeskAccessories.front(back: accessoriesBack)).y
        return size.width / max(size.height, lowest + camera.scale * 0.3)
    }
}
