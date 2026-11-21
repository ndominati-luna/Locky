import SwiftUI

/// How the logo comes in.
enum LogoIntro: Equatable {
    /// The wings unfold and beat, the padlock drops into their curls.
    case unfold
    /// The whole logo appears in a glow, sharpening and growing.
    case materialize
    /// The whole logo flies in like a bird from `distance` sides of the logo away (upper left),
    /// swoops down beating its wings, then flares up to land in place.
    case flyIn(distance: Double)

    /// When the title starts appearing, from the appearance of the logo.
    var titleStart: TimeInterval {
        switch self {
        case .unfold: 0.85
        case .materialize: 0.75
        case .flyIn: 1.45
        }
    }
}

/// How the logo leaves while unlocking, from 0 (shown) to 1 (gone).
enum LogoDeparture: Equatable {
    /// It grows, blurs and fades.
    case dissolve(Double)
    /// It takes off like a bird, beating faster and faster, and flies away to the upper right,
    /// `distance` sides of the logo away.
    case takeOff(Double, distance: Double)

    var progress: Double {
        switch self {
        case let .dissolve(progress), let .takeOff(progress, _): progress
        }
    }

    func with(progress: Double) -> LogoDeparture {
        switch self {
        case .dissolve: .dissolve(progress)
        case let .takeOff(_, distance): .takeOff(progress, distance: distance)
        }
    }
}

/// The Locky logo assembling itself, then its title appearing. Animatable: leaving, it is drawn
/// again at every step of its departure, so that the wings beat while it takes off (otherwise only
/// its position would be interpolated, the wings frozen).
struct AnimatedLockyLogo: View, @MainActor Animatable {
    let title: String
    var titleStyle: LockTitleStyle = .reveal
    /// Side of the logo; the title follows its size.
    var size: CGFloat = 220
    /// `nil`: shown already assembled (unlocking starts from the assembled logo).
    var intro: LogoIntro? = .unfold
    var departure: LogoDeparture = .dissolve(0)

    @State private var trigger: Bool = false

    var animatableData: Double {
        get { departure.progress }
        set { departure = departure.with(progress: newValue) }
    }

    /// The view is the square of the logo, so that it can be centered on the screen (the iris of
    /// the lock animation closes on its curls); the title hangs below it.
    var body: some View {
        // The parts are drawn from the animated value itself: passed down the environment of the
        // animated content, it never reached the wings (they stayed assembled, only the title moved).
        let title: String = title
        let titleStyle: LockTitleStyle = titleStyle
        let size: CGFloat = size
        let departure: LogoDeparture = departure
        Color.clear
            .frame(width: size, height: size)
            .keyframeAnimator(initialValue: intro.map(LogoState.start) ?? .assembled, trigger: trigger) { _, state in
                PosedLogo(state: state, title: title, titleStyle: titleStyle, size: size, departure: departure)
            } keyframes: { _ in
                keyframes
            }
            .modifier(Dissolve(departure: departure, size: size))
            .onAppear {
                if intro != nil {
                    trigger.toggle()
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(title))
    }

    @KeyframesBuilder<LogoState>
    private var keyframes: some Keyframes<LogoState> {
        let mode: Mode = .init(intro)
        KeyframeTrack(\.spread) {
            switch mode {
            case .unfold:
                LinearKeyframe(0, duration: 0.05)
                SpringKeyframe(1, duration: 0.7, spring: .init(duration: 0.7, bounce: 0.35))
            case .materialize:
                LinearKeyframe(0.6, duration: 0.1)
                SpringKeyframe(1, duration: 0.9, spring: .init(duration: 0.9, bounce: 0.3))
            case .flyIn:
                LinearKeyframe(1, duration: 0.01)
            }
        }
        KeyframeTrack(\.flap) {
            switch mode {
            case .unfold:
                LinearKeyframe(0, duration: 0.6)
                CubicKeyframe(-16, duration: 0.22)
                SpringKeyframe(4, duration: 0.3, spring: .bouncy)
                CubicKeyframe(-9, duration: 0.2)
                SpringKeyframe(0, duration: 0.5, spring: .smooth)
            case .materialize:
                LinearKeyframe(0, duration: 0.35)
                CubicKeyframe(-10, duration: 0.25)
                SpringKeyframe(3, duration: 0.3, spring: .bouncy)
                SpringKeyframe(0, duration: 0.5, spring: .smooth)
            case .flyIn:
                // Beating all the way in, then the wings rise to brake (the flare) and settle.
                CubicKeyframe(30, duration: 0.11)
                CubicKeyframe(-24, duration: 0.11)
                CubicKeyframe(30, duration: 0.11)
                CubicKeyframe(-24, duration: 0.11)
                CubicKeyframe(28, duration: 0.12)
                CubicKeyframe(-20, duration: 0.12)
                CubicKeyframe(26, duration: 0.13)
                CubicKeyframe(-12, duration: 0.13)
                CubicKeyframe(34, duration: 0.16)
                SpringKeyframe(0, duration: 0.55, spring: .bouncy)
            }
        }
        KeyframeTrack(\.lockDrop) {
            switch mode {
            case .unfold:
                LinearKeyframe(1, duration: 0.35)
                SpringKeyframe(0, duration: 0.65, spring: .init(duration: 0.65, bounce: 0.45))
            case .materialize:
                LinearKeyframe(0, duration: 0.01)
            case .flyIn:
                LinearKeyframe(0, duration: 0.01)
            }
        }
        KeyframeTrack(\.lockOpacity) {
            switch mode {
            case .unfold:
                LinearKeyframe(0, duration: 0.35)
                LinearKeyframe(1, duration: 0.2)
            case .materialize:
                LinearKeyframe(1, duration: 0.01)
            case .flyIn:
                LinearKeyframe(1, duration: 0.01)
            }
        }
        // The path of the flight: across and down from the upper left, a swoop just under the place
        // of the logo, then up into it as it lands.
        KeyframeTrack(\.flightX) {
            switch mode {
            case .unfold, .materialize:
                LinearKeyframe(0, duration: 0.01)
            case .flyIn:
                CubicKeyframe(flightDistance * -0.45, duration: 0.45)
                CubicKeyframe(flightDistance * -0.08, duration: 0.45)
                SpringKeyframe(0, duration: 0.6, spring: .init(duration: 0.6, bounce: 0.2))
            }
        }
        KeyframeTrack(\.flightY) {
            switch mode {
            case .unfold, .materialize:
                LinearKeyframe(0, duration: 0.01)
            case .flyIn:
                CubicKeyframe(-0.55, duration: 0.45)
                CubicKeyframe(0.22, duration: 0.45)
                SpringKeyframe(0, duration: 0.6, spring: .init(duration: 0.6, bounce: 0.35))
            }
        }
        KeyframeTrack(\.bank) {
            switch mode {
            case .unfold, .materialize:
                LinearKeyframe(0, duration: 0.01)
            case .flyIn:
                // Nose down while diving, up while braking.
                CubicKeyframe(10, duration: 0.45)
                CubicKeyframe(-12, duration: 0.45)
                SpringKeyframe(0, duration: 0.6, spring: .bouncy)
            }
        }
        KeyframeTrack(\.scale) {
            switch mode {
            case .materialize:
                SpringKeyframe(1, duration: 0.9, spring: .init(duration: 0.9, bounce: 0.25))
            case .flyIn:
                // Coming from afar.
                CubicKeyframe(0.82, duration: 0.6)
                SpringKeyframe(1, duration: 0.8, spring: .init(duration: 0.8, bounce: 0.2))
            case .unfold:
                LinearKeyframe(1, duration: 0.01)
            }
        }
        KeyframeTrack(\.blur) {
            switch mode {
            case .materialize:
                CubicKeyframe(0, duration: 0.7)
            case .unfold, .flyIn:
                LinearKeyframe(0, duration: 0.01)
            }
        }
        KeyframeTrack(\.opacity) {
            switch mode {
            case .materialize:
                LinearKeyframe(1, duration: 0.45)
            case .unfold, .flyIn:
                LinearKeyframe(1, duration: 0.01)
            }
        }
        KeyframeTrack(\.glow) {
            switch mode {
            case .materialize:
                CubicKeyframe(1, duration: 0.45)
                CubicKeyframe(0, duration: 1.0)
            case .unfold, .flyIn:
                LinearKeyframe(0, duration: 0.01)
            }
        }
        KeyframeTrack(\.title) {
            LinearKeyframe(0, duration: intro?.titleStart ?? 0)
            LinearKeyframe(1, duration: titleStyle.duration)
        }
    }

    private var flightDistance: Double {
        if case let .flyIn(distance) = intro {
            return distance
        }
        return 0
    }

    /// ``LogoIntro`` without its distance, for the keyframes.
    private enum Mode {
        case unfold
        case materialize
        case flyIn

        init(_ intro: LogoIntro?) {
            switch intro {
            case .unfold, nil: self = .unfold
            case .materialize: self = .materialize
            case .flyIn: self = .flyIn
            }
        }
    }
}

/// Values of the assembly animation.
struct LogoState {
    /// 0: wings folded up, 1: spread.
    var spread: Double
    /// Beat of the wings, in degrees.
    var flap: Double
    /// 1: padlock above, 0: in place.
    var lockDrop: Double
    var lockOpacity: Double
    /// Reveal of the title, from 0 to 1.
    var title: Double
    /// Position of the logo in flight, from its place, in sides of the logo.
    var flightX: Double
    var flightY: Double
    /// Tilt of the logo in flight, in degrees.
    var bank: Double
    var scale: Double
    /// 1: fully blurred, 0: sharp.
    var blur: Double
    var opacity: Double
    /// The glow behind the logo, from 0 to 1.
    var glow: Double

    static let assembled: LogoState = .init(
        spread: 1, flap: 0, lockDrop: 0, lockOpacity: 1, title: 1, flightX: 0, flightY: 0, bank: 0, scale: 1, blur: 0, opacity: 1, glow: 0
    )

    static func start(_ intro: LogoIntro) -> LogoState {
        switch intro {
        case .unfold:
            .init(spread: 0, flap: 0, lockDrop: 1, lockOpacity: 0, title: 0, flightX: 0, flightY: 0, bank: 0, scale: 1, blur: 0, opacity: 1, glow: 0)
        case .materialize:
            .init(spread: 0.6, flap: 0, lockDrop: 0, lockOpacity: 1, title: 0, flightX: 0, flightY: 0, bank: 0, scale: 0.72, blur: 1, opacity: 0, glow: 0)
        case let .flyIn(distance):
            .init(spread: 1, flap: 0, lockDrop: 0, lockOpacity: 1, title: 0, flightX: -distance, flightY: -1.3, bank: 18, scale: 0.55, blur: 0, opacity: 1, glow: 0)
        }
    }
}

/// The logo posed by ``LogoState``: wings, padlock, title and the glow it materializes from.
private struct PosedLogo: View {
    let state: LogoState
    let title: String
    let titleStyle: LockTitleStyle
    let size: CGFloat
    let departure: LogoDeparture

    var body: some View {
        LogoParts(state: state, size: size, departure: departure)
            .frame(width: size, height: size)
            .overlay(alignment: .top) {
                TitleReveal(state: state, title: title, style: titleStyle, size: size)
                    .frame(width: size * 3)
                    .offset(y: size * 1.02)
                    .opacity(titleOpacity)
            }
            .foregroundStyle(.white)
            .background {
                Circle()
                    .fill(.radialGradient(colors: [.white.opacity(0.55), .white.opacity(0)], center: .center, startRadius: 0, endRadius: size * 0.75))
                    .frame(width: size * 1.6, height: size * 1.6)
                    .opacity(state.glow)
                    .allowsHitTesting(false)
            }
            .rotationEffect(.degrees(state.bank + takeOff.bank))
            .scaleEffect(state.scale * takeOff.scale)
            .blur(radius: state.blur * size * 0.08)
            .opacity(state.opacity * takeOff.opacity)
            .offset(x: (state.flightX + takeOff.x) * size, y: (state.flightY + takeOff.y) * size)
    }

    private var titleOpacity: Double {
        if case let .takeOff(progress, _) = departure {
            return max(0, 1 - progress * 3)
        }
        return 1
    }

    /// Unlocking with the flight: up and away to the upper right, smaller as it goes, fading out at
    /// the end.
    private var takeOff: (x: Double, y: Double, bank: Double, scale: Double, opacity: Double) {
        guard case let .takeOff(progress, distance) = departure else { return (0, 0, 0, 1, 1) }
        return (
            x: distance * 0.9 * progress * progress,
            y: -(0.9 * progress + 1.8 * progress * progress),
            bank: 16 * progress,
            scale: 1 - 0.35 * progress,
            opacity: progress > 0.75 ? max(0, (1 - progress) / 0.25) : 1
        )
    }
}

/// Leaving by dissolving: the whole logo grows, blurs and fades.
private struct Dissolve: ViewModifier {
    let departure: LogoDeparture
    let size: CGFloat

    func body(content: Content) -> some View {
        if case let .dissolve(progress) = departure {
            content
                .scaleEffect(1 + 0.35 * progress)
                .opacity(1 - progress)
                .blur(radius: size * 0.045 * progress)
        } else {
            content
        }
    }
}

/// Wings and padlock, posed by ``LogoState``.
private struct LogoParts: View {
    let state: LogoState
    let size: CGFloat
    let departure: LogoDeparture

    var body: some View {
        // Folded, the wings point up along the padlock; spreading opens them.
        let raise: Angle = .degrees((1 - state.spread) * 62 + state.flap + takeOffBeat)
        ZStack {
            LockyWing(side: .left, flap: raise)
                .opacity(min(1, state.spread * 3))
            LockyWing(side: .right, flap: raise)
                .opacity(min(1, state.spread * 3))
            Image("LockyLock", bundle: .module)
                .resizable()
                .scaledToFit()
                .offset(y: -state.lockDrop * size * 0.6)
                .opacity(state.lockOpacity)
        }
        .frame(width: size, height: size)
    }

    /// Taking off: the wings beat, faster as the logo speeds up (the progress itself accelerates).
    private var takeOffBeat: Double {
        guard case let .takeOff(progress, _) = departure else { return 0 }
        return sin(progress * .pi * 8) * 30 * min(1, progress * 5)
    }
}

/// The title, appearing in its style.
private struct TitleReveal: View {
    let state: LogoState
    let title: String
    let style: LockTitleStyle
    let size: CGFloat

    var body: some View {
        Text(title)
            .font(.system(size: size * 0.19, weight: .light))
            .tracking(size * 0.04)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .textRenderer(TitleRenderer(style: style, progress: state.title))
            .shadow(color: .white.opacity(0.35 * state.title), radius: 12)
    }
}
