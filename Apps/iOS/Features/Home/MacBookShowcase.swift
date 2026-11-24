import LockyKit
import SwiftUI

/// A MacBook on the home screen, handled like the real one, without any button. Two fingers set
/// down on its lid fold it down or open it further, and it stays where it is let go. As it closes, the light of
/// its screen falls on the keyboard, until the screen goes dark, as a MacBook does when its lid is
/// nearly shut. Shut or opened as far as it goes, it gives a little knock. Three fingers set the
/// brightness of its screen. A double tap puts it back as it came: open as in its picture, at full
/// brightness. One finger pulls the whole Mac, the rubber band of the home screen. Disabled (the
/// Mac out of reach), it is left alone.
struct MacBookShowcase: View {
    let frame: MacFrame
    let outline: MacBookOutline
    var wallpaper: UIImage?
    let lockState: LockState
    var isConnected: Bool = true
    var userPicture: Data?
    var userName: String?
    var isUnlocking: Bool = false
    /// One finger: how far it pulled the Mac, then `nil` once let go.
    let pulled: (CGSize?) -> Void

    /// Degrees the lid is folded from its picture: 0 as drawn, 90 shut, below 0 opened further.
    @AppStorage("macBookFold") private var storedFold: Double = 0
    @AppStorage("macBookBrightness") private var storedBrightness: Double = 1
    /// Where the lid and the brightness rest once handled: state, which animates, unlike the stored
    /// values (a double tap puts the lid back smoothly).
    @State private var restingFold: Double?
    @State private var restingBrightness: Double?

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// The hands at work, on top of ``fold`` and ``brightness``, since their gesture began.
    @State private var folding: Double = 0
    @State private var brightening: Double = 0
    @State private var isPulling: Bool = false
    @State private var isFolding: Bool = false
    @State private var isBrightening: Bool = false
    /// More fingers came down during a gesture: it gave its place back and waits for its end.
    @State private var isPullSuspended: Bool = false
    @State private var isFoldSuspended: Bool = false
    @State private var isScreenOn: Bool = true
    @State private var wake: Task<Void, Never>?
    @State private var showsBrightness: Bool = false
    @State private var brightnessFade: Task<Void, Never>?
    @State private var stop: LidStop = .between
    @State private var haptics: HingeHaptics = .init()
    /// Where the lid last gave a grain under the fingers.
    @State private var lastGrain: Double = 0
    /// The height of the lid on screen, which the fingers travel to fold it.
    @State private var lidHeight: CGFloat = 1
    @State private var canvasSize: CGSize = .zero
    /// Two fingers came down on the lid: only they fold it.
    @State private var isOnLid: Bool = false

    /// Opened as far as a MacBook goes (about 130°), and shut on the keyboard.
    private static let foldRange: ClosedRange<Double> = -40...90
    /// The screen goes dark when the lid is nearly shut, and lights up again once it is clearly open.
    private static let screenOffFold: Double = 72
    private static let screenOnFold: Double = 64
    /// Degrees between two grains of the hinge under the fingers.
    private static let grainStep: Double = 2

    var body: some View {
        MacBookFold(
            fold: shownFold,
            image: frame.image,
            lidEdge: MacBookOutline.lidEdge(of: frame, outline: outline),
            outline: outline,
            screenRect: frame.screen ?? .init(x: 0, y: 0, width: 1, height: 1),
            wallpaper: wallpaper,
            screenLight: isScreenOn ? 0.3 + 0.7 * shownBrightness : 0
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
                if showsBrightness {
                    BrightnessIndicator(level: shownBrightness)
                        .transition(.opacity)
                }
            }
            .overlay {
                // Off, the glass of the screen.
                Color(white: 0.015)
                    .opacity(isScreenOn ? 0 : 1)
            }
        }
        .aspectRatio(frame.image.size, contentMode: .fit)
        .saturation(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.45), value: lockState)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            canvasSize = size
            lidHeight = max(size.height * outline.hinge, 1)
        }
        .contentShape(.rect)
        .gesture(HandPanRecognizer(touches: 1, isEnabled: isEnabled, changed: pull) { _ in endPull() })
        .gesture(HandPanRecognizer(touches: 2, isEnabled: isEnabled, began: twoFingersBegan, changed: foldChanged) { _ in endFold() })
        .gesture(HandPanRecognizer(touches: 3, isEnabled: isEnabled, changed: brightnessChanged) { _ in endBrightness() })
        .gesture(HandDoubleTapRecognizer(isEnabled: isEnabled, tapped: reset))
        .onAppear {
            isScreenOn = fold < Self.screenOffFold
        }
        .onChange(of: shownFold) {
            updateScreen()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "MacBook"))
        .accessibilityActions {
            if isEnabled {
                Button(fold >= 45 ? "Open the lid" : "Close the lid") {
                    rest(fold: fold >= 45 ? 0 : 90, animation: settling)
                }
                Button("Put the display back") {
                    reset()
                }
            }
        }
    }

    // MARK: What is shown: the resting lid and brightness, plus the hands

    private var fold: Double {
        restingFold ?? storedFold
    }

    private var brightness: Double {
        restingBrightness ?? storedBrightness
    }

    private var shownFold: Double {
        min(max(fold + folding, Self.foldRange.lowerBound), Self.foldRange.upperBound)
    }

    private var shownBrightness: Double {
        min(max(brightness + brightening, 0), 1)
    }

    private var settling: Animation? {
        reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.12)
    }

    // MARK: The hands

    private func pull(_ translation: CGSize) {
        guard !isPullSuspended, !isFolding, !isBrightening else { return }
        isPulling = true
        pulled(translation)
    }

    private func endPull() {
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

    /// Where the lid shows, folded as it is, for the fingers. More than half shut, it covers the
    /// deck: the whole Mac, so that it opens as easily as it closes.
    private var lidFrame: CGRect {
        if shownFold > 45 {
            return CGRect(origin: .zero, size: canvasSize)
        }
        let lid: LidProjection = .init(outline: outline, size: canvasSize)
        let transform: ProjectionTransform = lid.transform(fold: shownFold)
        let left: CGFloat = outline.lidLeft * canvasSize.width
        let right: CGFloat = outline.lidRight * canvasSize.width
        let corners: [CGPoint] = [
            projected(CGPoint(x: left, y: 0), by: transform),
            projected(CGPoint(x: right, y: 0), by: transform),
            projected(CGPoint(x: left, y: lid.hinge), by: transform),
            projected(CGPoint(x: right, y: lid.hinge), by: transform)
        ]
        var frame: CGRect = .null
        for corner in corners {
            frame = frame.union(CGRect(origin: corner, size: .zero))
        }
        return frame.insetBy(dx: -12, dy: -12)
    }

    private func twoFingersBegan(_ point: CGPoint) {
        guard !isFolding else { return }
        isOnLid = lidFrame.contains(point)
    }

    private func foldChanged(_ translation: CGSize) {
        moreFingersDown()
        guard isOnLid, !isFoldSuspended, !isBrightening else { return }
        if !isFolding {
            isFolding = true
            lastGrain = shownFold
        }
        // The top of the lid follows the fingers: down folds it, a little more than its height
        // shuts it.
        let wanted: Double = fold + Double(translation.height / lidHeight) * 95
        folding = min(max(wanted, Self.foldRange.lowerBound), Self.foldRange.upperBound) - fold
        // The hinge under the fingers: a knock at its stops, and a fine grain as it turns, which
        // keeps clear of the stops so that the knock comes alone.
        updateStop()
        if stop == .between, isClearOfStops, abs(shownFold - lastGrain) >= Self.grainStep {
            lastGrain = shownFold
            haptics.grain()
        }
    }

    /// Away from both stops by more than a degree.
    private var isClearOfStops: Bool {
        shownFold > Self.foldRange.lowerBound + 1 && shownFold < Self.foldRange.upperBound - 1
    }

    private func endFold() {
        isFoldSuspended = false
        isOnLid = false
        guard isFolding else { return }
        rest(fold: shownFold)
        folding = 0
        isFolding = false
    }

    private func brightnessChanged(_ translation: CGSize) {
        moreFingersDown()
        if isFolding {
            // A third finger came down: the lid goes back to where the two found it.
            withAnimation(settling) { folding = 0 }
            isFolding = false
            isFoldSuspended = true
        }
        isBrightening = true
        // Up brightens, the height of the lid from dark to full.
        let wanted: Double = brightness - Double(translation.height / lidHeight)
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

    /// Back as it came, from wherever the lid is, smoothly.
    private func reset() {
        rest(fold: shownFold, brightness: shownBrightness)
        folding = 0
        brightening = 0
        isFolding = false
        isBrightening = false
        stop = .between
        rest(fold: 0, brightness: 1, animation: settling)
    }

    /// Leaves the lid or the brightness there, and keeps it for the next time.
    private func rest(fold: Double? = nil, brightness: Double? = nil, animation: Animation? = nil) {
        withAnimation(animation) {
            if let fold {
                restingFold = fold
            }
            if let brightness {
                restingBrightness = brightness
            }
        }
        if let fold {
            storedFold = fold
        }
        if let brightness {
            storedBrightness = brightness
        }
    }

    /// A knock once the lid reaches a stop, not again until it has left it.
    private func updateStop() {
        let shown: Double = shownFold
        let previous: LidStop = stop
        if shown >= Self.foldRange.upperBound {
            stop = .shut
        } else if shown <= Self.foldRange.lowerBound {
            stop = .wideOpen
        } else if shown < Self.foldRange.upperBound - 2, shown > Self.foldRange.lowerBound + 2 {
            stop = .between
        }
        guard stop != previous, stop != .between else { return }
        haptics.knock(isDeep: stop == .shut)
    }

    /// Dark at once when the lid is nearly shut; lit again a moment after it opens, as macOS does.
    private func updateScreen() {
        if shownFold >= Self.screenOffFold {
            wake?.cancel()
            wake = nil
            if isScreenOn {
                withAnimation(.easeIn(duration: 0.18)) { isScreenOn = false }
            }
        } else if shownFold <= Self.screenOnFold, !isScreenOn, wake == nil {
            wake = Task {
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.45)) { isScreenOn = true }
                wake = nil
            }
        }
    }
}

/// Where `point` of a drawing shows once `transform` lays it down.
private func projected(_ point: CGPoint, by transform: ProjectionTransform) -> CGPoint {
    let depth: CGFloat = point.x * transform.m13 + point.y * transform.m23 + transform.m33
    let x: CGFloat = point.x * transform.m11 + point.y * transform.m21 + transform.m31
    let y: CGFloat = point.x * transform.m12 + point.y * transform.m22 + transform.m32
    return CGPoint(x: x / depth, y: y / depth)
}

private enum LidStop {
    case between
    case shut
    case wideOpen
}

/// The MacBook with its lid folded by `fold` degrees, seen through the camera of its picture. The
/// lid turns on its hinge; the deck and the front edge stay as drawn. Shut, the back of the lid
/// covers the deck. The light of the screen falls on the keys as the lid comes down over them, the
/// deck darkening under it.
private struct MacBookFold<Screen: View>: View, Animatable {
    var fold: Double
    let image: UIImage
    /// The front edge of the lid once shut, cut from the picture.
    let lidEdge: UIImage?
    let outline: MacBookOutline
    let screenRect: NormalizedRect
    let wallpaper: UIImage?
    /// The light the screen gives: 0 dark, 1 at full brightness.
    let screenLight: Double
    @ViewBuilder let screen: Screen

    nonisolated var animatableData: Double {
        get { fold }
        set { fold = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let lid: LidProjection = .init(outline: outline, size: proxy.size)
            // The top edge of the lid, between its inner face and its back: hidden behind the lid
            // while it is open, it shows more and more as it closes, until it stands on the front
            // of the deck once shut.
            let edge: LidProjection.Edge = lid.edge(fold: fold, thickness: thickness(size: proxy.size))
            let rise: CGFloat = max(0, edge.inner - edge.outer)
            ZStack(alignment: .topLeading) {
                // The deck and the front edge, under the hinge, and a point of the lid above it while
                // the screen shows: the edges of the two halves overlap, no thread of what lies
                // behind shows between them.
                Image(uiImage: image)
                    .resizable()
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: max(0, proxy.size.height - lid.hinge + (lid.showsScreen(fold) ? 1 : 0)))
                    }
                DeckShade(
                    image: image,
                    wallpaper: wallpaper,
                    lid: lid,
                    width: (outline.lidRight - outline.lidLeft) * proxy.size.width * outline.spread,
                    shadow: Self.smoothstep(fold, from: 30, to: 90) * 0.5,
                    // Closer and closer to the keys, the screen lights them more and more.
                    light: Self.smoothstep(fold, from: 5, to: 70) * screenLight
                )
                // Nearly shut, the back of the lid, as far behind its inner face as the lid is thick.
                if !lid.showsScreen(fold) {
                    LidShell(outline: outline, size: proxy.size, hinge: lid.hinge)
                        .projectionEffect(lid.backTransform(fold: fold, thickness: thickness(size: proxy.size)))
                }
                // The edge of the lid all along its top and around its rounded corners, as the
                // camera sees it, under the screen that overlaps it.
                LidRim(lid: lid, fold: fold, thickness: thickness(size: proxy.size), outline: outline, size: proxy.size)
                if lid.showsScreen(fold) {
                    ZStack {
                        ScreenRectLayout(rect: screenRect, outset: 1) {
                            screen
                        }
                        Image(uiImage: image)
                            .resizable()
                    }
                    .mask(alignment: .top) {
                        Rectangle()
                            .frame(height: lid.hinge)
                    }
                    .projectionEffect(lid.transform(fold: fold))
                }
                if rise > 0.3, let lidEdge {
                    // The aluminium of the straight part of the edge, from the picture: a face of
                    // the lid like the others, turned and seen in perspective with it, from the top
                    // of its back (the top of the picture, rounded) to the top of its inner face.
                    // Its ends melt into the rim, which turns around the corners.
                    let span: CGFloat = proxy.size.width / max(outline.spread, 1)
                    let size: CGSize = .init(width: max(span * edge.magnification, 1), height: max(rise, 1))
                    let straight: ClosedRange<CGFloat> = straightPart(span: span, width: proxy.size.width)
                    let fade: CGFloat = 0.025
                    Image(uiImage: lidEdge)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: size.width, height: size.height)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: straight.lowerBound),
                                    .init(color: .black, location: straight.lowerBound + fade),
                                    .init(color: .black, location: straight.upperBound - fade),
                                    .init(color: .clear, location: straight.upperBound)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        }
                        .projectionEffect(
                            lid.camera.surface(
                                size: size,
                                left: -span / 2,
                                width: span,
                                back: edge.outerDepth,
                                depth: edge.innerDepth - edge.outerDepth,
                                backHeight: edge.outerHeight,
                                frontHeight: edge.innerHeight
                            )
                        )
                        .allowsHitTesting(false)
                }
            }
        }
    }

    /// The straight part of the top of the lid, between its rounded corners, in fractions of the
    /// picture of the edge, `span` points wide face on.
    private func straightPart(span: CGFloat, width: CGFloat) -> ClosedRange<CGFloat> {
        let start: CGFloat = width / 2 - span / 2
        let corner: CGFloat = outline.lidTopInset * width
        let lower: CGFloat = (outline.lidLeft * width + corner - start) / max(span, 1)
        let upper: CGFloat = (outline.lidRight * width - corner - start) / max(span, 1)
        return max(0, lower)...min(1, max(upper, lower + 0.1))
    }

    /// How thick the lid is, face on: as its front edge shows once shut, on the front of the deck,
    /// which the camera sees `spread` times larger.
    private func thickness(size: CGSize) -> CGFloat {
        (outline.deckBottom - outline.deckFront) * MacBookOutline.edgeThickness * size.height / max(outline.spread, 1)
    }

    static func smoothstep(_ value: Double, from start: Double, to end: Double) -> Double {
        let t: Double = min(max((value - start) / (end - start), 0), 1)
        return t * t * (3 - 2 * t)
    }
}

/// The lid as the camera of the picture sees it turn on its hinge. The picture shows it face on,
/// the deck behind as a thin strip that widens toward its front edge: the camera is a little above
/// the hinge, close enough for that perspective. Shut, the lid lies on the deck, its top on the
/// front edge; both are as deep, which gives the distance and the height of the camera.
private struct LidProjection {
    let width: CGFloat
    /// Down from the top of the picture, in points.
    let hinge: CGFloat
    /// From the hinge down to the front edge of the deck, which the lid covers once shut.
    let deck: CGFloat
    /// From the lid face on to the camera, and the camera above the hinge, in points.
    let distance: CGFloat
    let eyeHeight: CGFloat

    init(outline: MacBookOutline, size: CGSize) {
        width = size.width
        hinge = outline.hinge * size.height
        deck = max(1, (outline.deckFront - outline.hinge) * size.height)
        let spread: CGFloat = max(outline.spread, 1.05)
        distance = max(hinge, 1) * spread / (spread - 1)
        eyeHeight = deck / (spread - 1)
    }

    /// The top edge of the lid folded by `fold`, `thickness` points thick: where the top of its inner
    /// face and of its back show, from the top of the picture, and how much larger than face on.
    struct Edge {
        let inner: CGFloat
        let outer: CGFloat
        let magnification: CGFloat
        /// Above the hinge and toward the camera, in points: the top of the inner face and of the back.
        let innerHeight: CGFloat
        let innerDepth: CGFloat
        let outerHeight: CGFloat
        let outerDepth: CGFloat
    }

    /// The back of the lid folded by `fold`, `thickness` points behind its inner face: the lid
    /// drawn face on, from its top to its hinge, laid on that plane.
    func backTransform(fold: Double, thickness: CGFloat) -> ProjectionTransform {
        let sine: CGFloat = CGFloat(sin(fold * .pi / 180))
        let cosine: CGFloat = CGFloat(cos(fold * .pi / 180))
        return camera.surface(
            size: CGSize(width: width, height: max(hinge, 1)),
            left: -width / 2,
            width: width,
            back: hinge * sine - thickness * cosine,
            depth: -hinge * sine,
            backHeight: hinge * cosine + thickness * sine,
            frontHeight: thickness * sine
        )
    }

    /// The same camera, for what turns with the lid off its plane: the hinge is its desk.
    var camera: DeskCamera {
        .init(scale: 1, center: width / 2, desk: hinge, distance: distance, eyeHeight: eyeHeight)
    }

    func edge(fold: Double, thickness: CGFloat) -> Edge {
        let radians: Double = fold * .pi / 180
        let sine: CGFloat = CGFloat(sin(radians))
        let cosine: CGFloat = CGFloat(cos(radians))
        // Above the hinge and toward the camera: the top of the inner face, then its back, behind
        // it along the lid.
        let innerHeight: CGFloat = hinge * cosine
        let innerDepth: CGFloat = hinge * sine
        let outerHeight: CGFloat = innerHeight + thickness * sine
        let outerDepth: CGFloat = innerDepth - thickness * cosine
        func shown(height: CGFloat, depth: CGFloat) -> CGFloat {
            hinge - eyeHeight + (eyeHeight - height) * distance / max(distance - depth, 1)
        }
        return .init(
            inner: shown(height: innerHeight, depth: innerDepth),
            outer: shown(height: outerHeight, depth: outerDepth),
            magnification: distance / max(distance - innerDepth, 1),
            innerHeight: innerHeight,
            innerDepth: innerDepth,
            outerHeight: outerHeight,
            outerDepth: outerDepth
        )
    }

    /// Whether the camera sees the screen, or the back of the lid, nearly shut.
    func showsScreen(_ fold: Double) -> Bool {
        let radians: Double = fold * .pi / 180
        return Double(distance) * cos(radians) > Double(eyeHeight) * sin(radians)
    }

    /// The perspective of the lid folded by `fold` degrees, its hinge in place: a point of the lid
    /// face on, `v` above the hinge, goes `v sin(fold)` toward the camera and `v cos(fold)` up.
    func transform(fold: Double) -> ProjectionTransform {
        let radians: Double = fold * .pi / 180
        let sine: CGFloat = CGFloat(sin(radians))
        let cosine: CGFloat = CGFloat(cos(radians))
        let depth: CGFloat = sine / distance
        var transform: ProjectionTransform = .init()
        transform.m11 = 1
        transform.m12 = 0
        transform.m13 = 0
        transform.m21 = width * depth / 2
        transform.m22 = (hinge - eyeHeight) * depth + cosine
        transform.m23 = depth
        transform.m31 = -width * hinge * depth / 2
        transform.m32 = (hinge - eyeHeight) * (1 - hinge * depth) - hinge * cosine + eyeHeight
        transform.m33 = 1 - hinge * depth
        return transform
    }
}

/// The deck under the lid: darker as the lid comes down over it, lit by the screen, its colours
/// thrown on the keys.
private struct DeckShade: View {
    let image: UIImage
    let wallpaper: UIImage?
    let lid: LidProjection
    /// The width of the front of the deck, in points.
    let width: CGFloat
    let shadow: Double
    let light: Double

    var body: some View {
        GeometryReader { proxy in
            let deck: CGFloat = lid.deck
            ZStack {
                Color.black
                    .opacity(shadow)
                Group {
                    if let wallpaper {
                        // The screen faces the keys: its picture lands upside down, its colours
                        // glowing on them.
                        Image(uiImage: wallpaper)
                            .resizable()
                            .scaleEffect(x: 1, y: -1)
                            .saturation(1.4)
                            .brightness(0.12)
                    } else {
                        Color(white: 0.8)
                    }
                }
                .frame(width: width, height: deck)
                .blur(radius: deck * 0.35)
                .mask {
                    // Brighter close to the screen.
                    LinearGradient(colors: [.white, .white.opacity(0.45)], startPoint: .top, endPoint: .bottom)
                }
                .blendMode(.plusLighter)
                .opacity(light * 0.9)
            }
            .frame(width: width, height: deck)
            .position(x: proxy.size.width / 2, y: lid.hinge + deck / 2)
        }
        .mask {
            Image(uiImage: image)
                .resizable()
        }
        .allowsHitTesting(false)
    }
}

/// The shell of the lid, drawn face on from its top to its hinge: its outline with its rounded top
/// corners, its aluminium carrying on from the top of its front edge, a little lighter toward the
/// hinge (its back, once the lid is nearly shut).
private struct LidShell: View {
    let outline: MacBookOutline
    let size: CGSize
    let hinge: CGFloat

    var body: some View {
        let left: CGFloat = outline.lidLeft * size.width
        let right: CGFloat = outline.lidRight * size.width
        let corner: CGFloat = outline.lidTopInset * size.width
        UnevenRoundedRectangle(topLeadingRadius: corner, topTrailingRadius: corner)
            .fill(
                LinearGradient(
                    colors: [outline.edgeTop, outline.edgeTop.mix(with: .white, by: 0.14)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: right - left, height: hinge)
            .offset(x: left)
            .frame(width: size.width, height: max(hinge, 1), alignment: .topLeading)
    }
}

/// The edge of the lid all along its top and around its rounded corners: the band between its
/// inner face and its back, built piece by piece in space and seen by the camera of the picture,
/// each piece shaded by how much it faces the camera, those that face away left out. Shut, its
/// corners are the rounded ends of the front edge; raised, they run down the sides of the screen.
private struct LidRim: View {
    let lid: LidProjection
    let fold: Double
    let thickness: CGFloat
    let outline: MacBookOutline
    let size: CGSize

    /// Pieces in each rounded corner.
    private static let steps: Int = 12

    var body: some View {
        Canvas { context, _ in
            for piece in pieces() {
                context.fill(piece.path, with: .color(piece.colour))
                // Over the seams between the pieces; round joins, for the mitres of the thinnest
                // pieces would stick out past the edge.
                context.stroke(piece.path, with: .color(piece.colour), style: StrokeStyle(lineWidth: 0.6, lineJoin: .round))
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private struct Piece {
        let path: Path
        let colour: Color
        /// How much it faces the camera: the pieces turned away are drawn first, under the others,
        /// whichever corner they belong to.
        let facing: CGFloat
    }

    private func pieces() -> [Piece] {
        let radians: Double = fold * .pi / 180
        let sine: CGFloat = CGFloat(sin(radians))
        let cosine: CGFloat = CGFloat(cos(radians))
        let camera: DeskCamera = lid.camera
        let left: CGFloat = outline.lidLeft * size.width
        let right: CGFloat = outline.lidRight * size.width
        let radius: CGFloat = max(outline.lidTopInset * size.width, 0.5)

        // The outline of the top of the lid, drawn face on, with its outward direction (across,
        // toward the top of the lid): up the left corner from the side, along the top, down the
        // right corner, a little inside the screen, which covers it.
        var outline: [(point: CGPoint, normal: CGVector)] = []
        for step in 0...Self.steps {
            let angle: CGFloat = (1 - CGFloat(step) / CGFloat(Self.steps)) * .pi / 2
            let normal: CGVector = .init(dx: -sin(angle), dy: cos(angle))
            outline.append((CGPoint(x: left + radius - radius * sin(angle), y: radius - radius * cos(angle)), normal))
        }
        for step in 0...Self.steps {
            let angle: CGFloat = CGFloat(step) / CGFloat(Self.steps) * .pi / 2
            let normal: CGVector = .init(dx: sin(angle), dy: cos(angle))
            outline.append((CGPoint(x: right - radius + radius * sin(angle), y: radius - radius * cos(angle)), normal))
        }

        /// Where a point of the lid face on is in space: across from the middle, above the hinge,
        /// toward the camera; `behind` along the lid, toward its back.
        func place(_ point: CGPoint, behind: CGFloat) -> (x: CGFloat, height: CGFloat, depth: CGFloat) {
            let above: CGFloat = lid.hinge - point.y
            return (point.x - size.width / 2, above * cosine + behind * sine, above * sine - behind * cosine)
        }
        func shown(_ place: (x: CGFloat, height: CGFloat, depth: CGFloat)) -> CGPoint {
            camera.point(x: place.x, height: place.height, depth: place.depth)
        }

        /// How much a point of the outline faces the camera: 1 straight at it, 0 edge on.
        func toward(_ entry: (point: CGPoint, normal: CGVector)) -> CGFloat {
            let middle = place(entry.point, behind: thickness / 2)
            let facing: (x: CGFloat, height: CGFloat, depth: CGFloat) = (entry.normal.dx, entry.normal.dy * cosine, entry.normal.dy * sine)
            let view: (x: CGFloat, height: CGFloat, depth: CGFloat) = (-middle.x, lid.eyeHeight - middle.height, lid.distance - middle.depth)
            let length: CGFloat = sqrt(view.x * view.x + view.height * view.height + view.depth * view.depth)
                * sqrt(facing.x * facing.x + facing.height * facing.height + facing.depth * facing.depth)
            return (facing.x * view.x + facing.height * view.height + facing.depth * view.depth) / max(length, 0.0001)
        }
        /// The edge is rounded where it meets the back and the inner face. Nearly shut, right over
        /// the front of the deck, that shows at its ends: as it turns away around a corner, it
        /// shows less and less of its height, its end rounded like those of the deck. Open, its
        /// ends turn behind the screen, which covers them.
        let rounding: CGFloat = CGFloat(MacBookFold<EmptyView>.smoothstep(fold, from: 84, to: 88))
        func profile(_ toward: CGFloat) -> CGFloat {
            let turn: CGFloat = 0.35
            guard toward < turn, rounding > 0 else { return 1 }
            let away: CGFloat = 1 - max(toward, 0) / turn
            return 1 - rounding * (1 - sqrt(max(0, 1 - away * away)))
        }
        // While the screen shows, a little inside it at the bottom, so that no thread shows.
        let inset: CGFloat = lid.showsScreen(fold) ? 0.6 : 0
        func band(_ entry: (point: CGPoint, normal: CGVector), toward: CGFloat) -> (top: CGPoint, bottom: CGPoint) {
            let half: CGFloat = thickness / 2 * profile(toward)
            let tucked: CGFloat = inset
            let inner: CGPoint = .init(x: entry.point.x - entry.normal.dx * tucked, y: entry.point.y + entry.normal.dy * tucked)
            return (
                shown(place(entry.point, behind: thickness / 2 + half)),
                shown(place(inner, behind: thickness / 2 - half))
            )
        }

        var pieces: [Piece] = []
        let towards: [CGFloat] = outline.map(toward)
        for index in 0..<(outline.count - 1) {
            let first = outline[index]
            let second = outline[index + 1]
            guard towards[index] > 0 || towards[index + 1] > 0 else { continue }
            let a = band(first, toward: towards[index])
            let b = band(second, toward: towards[index + 1])
            var path: Path = .init()
            path.move(to: a.bottom)
            path.addLine(to: b.bottom)
            path.addLine(to: b.top)
            path.addLine(to: a.top)
            path.closeSubpath()
            // The aluminium of the top of the edge, darker as it turns away.
            let facing: CGFloat = max(0, (towards[index] + towards[index + 1]) / 2)
            pieces.append(.init(path: path, colour: self.outline.edgeTop.mix(with: .black, by: Double(0.25 * (1 - facing))), facing: facing))
        }
        pieces.sort { $0.facing < $1.facing }
        return pieces
    }
}
