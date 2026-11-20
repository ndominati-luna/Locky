import SwiftUI

/// The Locky logo assembling itself: the wings unfold and beat, the padlock drops into their
/// curls, then the title appears glyph by glyph.
struct AnimatedLockyLogo: View {
    let title: String
    /// Side of the logo; the title follows its size.
    var size: CGFloat = 220
    /// `false`: shown already assembled (unlocking starts from the assembled logo).
    var animated: Bool = true

    @State private var trigger: Bool = false

    /// The view is the square of the logo, so that it can be centered on the screen (the iris of
    /// the lock animation closes on its curls); the title hangs below it.
    var body: some View {
        LogoParts(size: size)
            .frame(width: size, height: size)
            .overlay(alignment: .top) {
                TitleReveal(title: title, size: size)
                    .frame(width: size * 3)
                    .offset(y: size * 1.02)
            }
            .foregroundStyle(.white)
        .keyframeAnimator(initialValue: animated ? LogoState.start : LogoState.assembled, trigger: trigger) { content, state in
            content.environment(\.logoState, state)
        } keyframes: { _ in
            KeyframeTrack(\.spread) {
                LinearKeyframe(0, duration: 0.05)
                SpringKeyframe(1, duration: 0.7, spring: .init(duration: 0.7, bounce: 0.35))
            }
            KeyframeTrack(\.flap) {
                LinearKeyframe(0, duration: 0.6)
                CubicKeyframe(-16, duration: 0.22)
                SpringKeyframe(4, duration: 0.3, spring: .bouncy)
                CubicKeyframe(-9, duration: 0.2)
                SpringKeyframe(0, duration: 0.5, spring: .smooth)
            }
            KeyframeTrack(\.lockDrop) {
                LinearKeyframe(1, duration: 0.35)
                SpringKeyframe(0, duration: 0.65, spring: .init(duration: 0.65, bounce: 0.45))
            }
            KeyframeTrack(\.lockOpacity) {
                LinearKeyframe(0, duration: 0.35)
                LinearKeyframe(1, duration: 0.2)
            }
            KeyframeTrack(\.title) {
                LinearKeyframe(0, duration: 0.85)
                LinearKeyframe(1, duration: 1.0)
            }
        }
        .onAppear {
            if animated {
                trigger.toggle()
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(title))
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

    static let start: LogoState = .init(spread: 0, flap: 0, lockDrop: 1, lockOpacity: 0, title: 0)
    static let assembled: LogoState = .init(spread: 1, flap: 0, lockDrop: 0, lockOpacity: 1, title: 1)
}

extension EnvironmentValues {
    @Entry var logoState: LogoState = .assembled
}

/// Wings and padlock, posed by ``LogoState``.
private struct LogoParts: View {
    @Environment(\.logoState) private var state
    let size: CGFloat

    var body: some View {
        // Folded, the wings point up along the padlock; spreading opens them.
        let raise: Angle = .degrees((1 - state.spread) * 62 + state.flap)
        ZStack {
            LockyWing(side: .left, flap: raise)
                .opacity(min(1, state.spread * 3))
            LockyWing(side: .right, flap: raise)
                .opacity(min(1, state.spread * 3))
            Image(.lockyLock)
                .resizable()
                .scaledToFit()
                .offset(y: -state.lockDrop * size * 0.6)
                .opacity(state.lockOpacity)
        }
        .frame(width: size, height: size)
    }
}

/// The title, revealed glyph by glyph.
private struct TitleReveal: View {
    @Environment(\.logoState) private var state
    let title: String
    let size: CGFloat

    var body: some View {
        Text(title)
            .font(.system(size: size * 0.19, weight: .light))
            .tracking(size * 0.04)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .textRenderer(GlyphRevealRenderer(progress: state.title))
            .shadow(color: .white.opacity(0.35 * state.title), radius: 12)
    }
}
