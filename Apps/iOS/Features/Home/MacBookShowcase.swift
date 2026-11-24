import LockyKit
import SwiftUI

/// A MacBook on the home screen, handled like the real one, without any button. Two fingers fold
/// its lid down or open it further, and it stays where it is let go. As it closes, the light of
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
    @State private var haptics: LidHaptics = .init()
    /// Where the lid last gave a grain under the fingers.
    @State private var lastGrain: Double = 0
    /// The height of the lid on screen, which the fingers travel to fold it.
    @State private var lidHeight: CGFloat = 1

    /// Opened as far as a MacBook goes (about 130°), and shut on the keyboard.
    private static let foldRange: ClosedRange<Double> = -40...90
    /// The screen goes dark when the lid is nearly shut, and lights up again once it is clearly open.
    private static let screenOffFold: Double = 72
    private static let screenOnFold: Double = 64
    /// Degrees between two grains of the hinge under the fingers.
    private static let grainStep: Double = 2.5

    var body: some View {
        MacBookFold(
            fold: shownFold,
            image: frame.image,
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
        .onGeometryChange(for: CGFloat.self) { $0.size.height * outline.hinge } action: { lidHeight = max($0, 1) }
        .contentShape(.rect)
        .gesture(HandPanRecognizer(touches: 1, isEnabled: isEnabled, changed: pull) { _ in endPull() })
        .gesture(HandPanRecognizer(touches: 2, isEnabled: isEnabled, changed: foldChanged) { _ in endFold() })
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

    private func foldChanged(_ translation: CGSize) {
        moreFingersDown()
        guard !isFoldSuspended, !isBrightening else { return }
        if !isFolding {
            isFolding = true
            lastGrain = shownFold
        }
        // The top of the lid follows the fingers: down folds it, a little more than its height
        // shuts it.
        let wanted: Double = fold + Double(translation.height / lidHeight) * 95
        folding = min(max(wanted, Self.foldRange.lowerBound), Self.foldRange.upperBound) - fold
        // The hinge under the fingers: a fine grain as it turns, a knock at its stops.
        if abs(shownFold - lastGrain) >= Self.grainStep {
            lastGrain = shownFold
            haptics.grain()
        }
        updateStop()
    }

    private func endFold() {
        isFoldSuspended = false
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
        haptics.knock(isShut: stop == .shut)
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
            ZStack(alignment: .topLeading) {
                // The deck and the front edge, under the hinge.
                Image(uiImage: image)
                    .resizable()
                    .mask(alignment: .bottom) {
                        Rectangle()
                            .frame(height: max(0, proxy.size.height - lid.hinge))
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
                Group {
                    if lid.showsScreen(fold) {
                        ZStack {
                            ScreenRectLayout(rect: screenRect) {
                                screen
                            }
                            Image(uiImage: image)
                                .resizable()
                        }
                        .mask(alignment: .top) {
                            Rectangle()
                                .frame(height: lid.hinge)
                        }
                    } else {
                        LidBack(outline: outline, size: proxy.size, hinge: lid.hinge)
                    }
                }
                .projectionEffect(lid.transform(fold: fold))
            }
        }
    }

    private static func smoothstep(_ value: Double, from start: Double, to end: Double) -> Double {
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

/// The back of the lid, which shows once it is shut: its aluminium, lit toward the front.
private struct LidBack: View {
    let outline: MacBookOutline
    let size: CGSize
    let hinge: CGFloat

    var body: some View {
        let width: CGFloat = (outline.lidRight - outline.lidLeft) * size.width
        let corner: CGFloat = width * 0.03
        UnevenRoundedRectangle(topLeadingRadius: corner, topTrailingRadius: corner)
            .fill(
                LinearGradient(
                    colors: [
                        outline.aluminium.mix(with: .white, by: 0.12),
                        outline.aluminium.mix(with: .black, by: 0.12)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: width, height: hinge)
            .offset(x: outline.lidLeft * size.width)
            .frame(width: size.width, height: size.height, alignment: .topLeading)
    }
}

/// The brightness of the screen, at its top right, as macOS shows it while it changes.
private struct BrightnessIndicator: View {
    let level: Double

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width * 0.3
            let height: CGFloat = width * 0.2
            let symbol: CGFloat = height * 0.5
            let bar: CGFloat = width - height * 0.6 - symbol - height * 0.25
            HStack(spacing: height * 0.25) {
                Image(systemName: "sun.max.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: symbol, height: symbol)
                Capsule()
                    .fill(.white.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: max(height * 0.22, bar * level))
                    }
                    .frame(width: bar, height: height * 0.22)
            }
            .foregroundStyle(.white)
            .frame(width: width, height: height)
            .background(.black.opacity(0.45), in: .rect(cornerRadius: height * 0.35))
            .position(x: proxy.size.width - proxy.size.width * 0.03 - width / 2, y: proxy.size.height * 0.06 + height / 2)
        }
        .accessibilityHidden(true)
    }
}
