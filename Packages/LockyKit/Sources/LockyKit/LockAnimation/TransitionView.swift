import SwiftUI

/// Full screen animation played while locking and unlocking, in the style of ``LockAnimation``,
/// over its background (black by default).
///
/// - Iris: the desktop fades into the wallpaper; an iris closes on the ring of the logo, drawing the
///   wallpaper in; the wings unfold around the last bubble, the padlock drops and swallows it.
/// - Halo: the desktop fades into the wallpaper, which then blurs and melts into the background
///   while the logo appears in a glow.
/// - Flight: the background fades in over the desktop while the logo flies in like a bird and lands
///   in place.
/// - Curtain: two panels of background slide over the desktop and meet behind the logo.
///
/// Unlocking plays each one backwards, down to the wallpaper (the overlays then fade into the
/// desktop). Locking starts transparent: the real desktop, windows included, shows through (no
/// screen capture needed).
public struct TransitionView: View {
    public enum Kind: Sendable {
        case locking
        case unlocking
    }

    let kind: Kind
    let animation: LockAnimation
    let backdrop: LockBackdrop
    /// The wallpaper of the display: it stands for the desktop.
    let desktop: PlatformImage?
    let logoSize: CGFloat

    @State private var size: CGSize = .zero
    @State private var coverOpacity: Double
    /// Iris: 0 open on the whole screen, 1 closed on the ring of the logo.
    @State private var iris: Double
    /// Iris: the bubble of wallpaper left in the ring, 1 shown, 0 swallowed by the padlock.
    @State private var bubble: Double
    /// Halo: 0 the wallpaper is sharp, 1 it has melted into the background.
    @State private var melt: Double
    /// Flight: opacity of the background.
    @State private var backdropOpacity: Double
    /// Curtain: 0 open, 1 closed.
    @State private var doors: Double
    @State private var showsLogo: Bool
    /// Unlocking: 0 the logo is shown, 1 it has left.
    @State private var departure: Double = 0

    public init(kind: Kind, animation: LockAnimation, backdrop: LockBackdrop, desktop: PlatformImage?, logoSize: CGFloat) {
        self.kind = kind
        self.animation = animation
        self.backdrop = backdrop
        self.desktop = desktop
        self.logoSize = logoSize
        let locking: Bool = kind == .locking
        // Iris and halo start from the wallpaper fading in; flight and curtain from the desktop.
        let fadesIn: Bool = locking && (animation.style == .iris || animation.style == .halo)
        _coverOpacity = .init(initialValue: fadesIn ? 0 : 1)
        _iris = .init(initialValue: locking ? 0 : 1)
        _bubble = .init(initialValue: locking ? 1 : 0)
        _melt = .init(initialValue: locking ? 0 : 1)
        _backdropOpacity = .init(initialValue: locking ? 0 : 1)
        _doors = .init(initialValue: locking ? 0 : 1)
        _showsLogo = .init(initialValue: !locking)
    }

    public var body: some View {
        ZStack {
            layers
            if showsLogo {
                AnimatedLockyLogo(
                    title: animation.title,
                    titleStyle: animation.titleStyle,
                    size: logoSize,
                    intro: kind == .locking ? animation.style.intro(flightDistance: flightDistance) : nil,
                    departure: logoDeparture
                )
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .opacity(coverOpacity)
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
        .task {
            switch kind {
            case .locking: await playLocking()
            case .unlocking: await playUnlocking()
            }
        }
    }

    @ViewBuilder
    private var layers: some View {
        switch animation.style {
        case .iris:
            LockBackdropView(backdrop: backdrop, desktop: desktop, blurRadius: blurRadius)
            IrisLayer(
                image: desktop,
                size: size,
                center: irisCenter,
                ringDiameter: 2 * (LockyWing.curlRadius * logoSize - 4),
                iris: iris,
                bubble: bubble
            )
        case .halo:
            LockBackdropView(backdrop: backdrop, desktop: desktop, blurRadius: blurRadius)
            desktopImage
                .blur(radius: blurRadius * melt)
                .scaleEffect(1 + 0.08 * melt)
                .opacity(1 - melt)
        case .flight:
            if kind == .unlocking {
                desktopImage
            }
            LockBackdropView(backdrop: backdrop, desktop: desktop, blurRadius: blurRadius)
                .opacity(backdropOpacity)
        case .curtain:
            if kind == .unlocking {
                desktopImage
            }
            CurtainLayer(backdrop: backdrop, desktop: desktop, blurRadius: blurRadius, size: size, closure: doors)
        case .none:
            EmptyView()
        }
    }

    /// The wallpaper filling the screen, black without it.
    private var desktopImage: some View {
        Color.black
            .overlay {
                if let desktop {
                    Image(platformImage: desktop)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
    }

    private var logoDeparture: LogoDeparture {
        animation.style == .flight ? .takeOff(departure, distance: flightDistance) : .dissolve(departure)
    }

    // MARK: - Locking

    private func playLocking() async {
        switch animation.style {
        case .iris:
            withAnimation(.easeInOut(duration: LockAnimationTiming.fadeDuration)) {
                coverOpacity = 1
            }
            try? await Task.sleep(for: .seconds(LockAnimationTiming.fadeDuration))
            withAnimation(.easeInOut(duration: LockAnimationTiming.irisDuration)) {
                iris = 1
            }
            // The wings unfold around the bubble as it reaches the ring.
            try? await Task.sleep(for: .seconds(LockAnimationTiming.irisDuration * 0.7))
            showLogo()
            // The padlock lands in the ring and swallows the last bubble of wallpaper.
            try? await Task.sleep(for: .seconds(0.75))
            withAnimation(.easeIn(duration: 0.3)) {
                bubble = 0
            }
        case .halo:
            withAnimation(.easeInOut(duration: 0.6)) {
                coverOpacity = 1
            }
            try? await Task.sleep(for: .seconds(0.5))
            withAnimation(.easeInOut(duration: 1.3)) {
                melt = 1
            }
            try? await Task.sleep(for: .seconds(animation.style.logoDelay - 0.5))
            showLogo()
        case .flight:
            withAnimation(.easeInOut(duration: 0.9)) {
                backdropOpacity = 1
            }
            try? await Task.sleep(for: .seconds(animation.style.logoDelay))
            showLogo()
        case .curtain:
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: animation.style.logoDelay)) {
                doors = 1
            }
            try? await Task.sleep(for: .seconds(animation.style.logoDelay))
            showLogo()
        case .none:
            break
        }
    }

    private func showLogo() {
        withAnimation(.easeOut(duration: 0.3)) {
            showsLogo = true
        }
    }

    // MARK: - Unlocking

    private func playUnlocking() async {
        switch animation.style {
        case .iris:
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.25)) {
                bubble = 1
            }
            withAnimation(.easeIn(duration: 0.6)) {
                departure = 1
            }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeInOut(duration: 0.9)) {
                iris = 0
            }
        case .halo:
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeIn(duration: 0.6)) {
                departure = 1
            }
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeInOut(duration: 0.85)) {
                melt = 0
            }
        case .flight:
            try? await Task.sleep(for: .milliseconds(150))
            withAnimation(.easeIn(duration: 0.95)) {
                departure = 1
            }
            try? await Task.sleep(for: .milliseconds(300))
            withAnimation(.easeInOut(duration: 0.85)) {
                backdropOpacity = 0
            }
        case .curtain:
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.easeIn(duration: 0.4)) {
                departure = 1
            }
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.timingCurve(0.65, 0, 0.35, 1, duration: 0.85)) {
                doors = 0
            }
        case .none:
            break
        }
    }

    // MARK: - Geometry

    /// Center of the ring between the curls of the wings: the logo is centered on the screen.
    private var irisCenter: CGPoint {
        .init(x: size.width / 2, y: size.height / 2 + (LockyWing.curlCenter.y - 0.5) * logoSize)
    }

    /// Flight: from the center to beyond the edge of the screen, in sides of the logo.
    private var flightDistance: Double {
        guard logoSize > 0 else { return 4 }
        return max(2, Double(size.width / 2 / logoSize) + 0.6)
    }

    /// Blur of the wallpaper behind the logo, in proportion to the screen.
    private var blurRadius: CGFloat {
        logoSize * 0.18
    }
}

/// The background of the animation: a color, the wallpaper of the display blurred and darkened, or
/// an image.
struct LockBackdropView: View {
    let backdrop: LockBackdrop
    let desktop: PlatformImage?
    let blurRadius: CGFloat

    var body: some View {
        switch backdrop {
        case let .color(color):
            color
        case .wallpaper:
            Color.black
                .overlay {
                    if let desktop {
                        Image(platformImage: desktop)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: blurRadius, opaque: true)
                            .overlay(Color.black.opacity(0.3))
                    }
                }
                .clipped()
        case let .image(image):
            Color.black
                .overlay {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                }
                .clipped()
        }
    }
}

/// Two panels of background sliding from the sides of the screen and meeting in the middle, with
/// a thin light along the seam as they close.
private struct CurtainLayer: View {
    let backdrop: LockBackdrop
    let desktop: PlatformImage?
    let blurRadius: CGFloat
    let size: CGSize
    /// 0: open, 1: closed.
    let closure: Double

    var body: some View {
        let half: CGFloat = size.width / 2
        ZStack {
            door(alignment: .leading)
                .offset(x: -half * (1 - closure))
            door(alignment: .trailing)
                .offset(x: half * (1 - closure))
            Rectangle()
                .fill(.white)
                .frame(width: 2, height: size.height)
                .shadow(color: .white.opacity(0.9), radius: 12)
                .opacity(seamLight)
        }
        .frame(width: size.width, height: size.height)
    }

    /// The seam lights up as the panels meet and goes out once they are closed.
    private var seamLight: Double {
        guard closure < 1 else { return 0 }
        return max(0, 1 - abs(closure - 0.9) / 0.1)
    }

    /// One half of the background, so that both halves make it whole once closed.
    private func door(alignment: Alignment) -> some View {
        LockBackdropView(backdrop: backdrop, desktop: desktop, blurRadius: blurRadius)
            .frame(width: size.width, height: size.height)
            .mask(alignment: alignment) {
                Rectangle()
                    .frame(width: size.width / 2)
            }
            // Depth while sliding, none once closed: both shadows would darken the seam.
            .shadow(color: .black.opacity(0.45 * (1 - min(1, closure))), radius: 24)
    }
}
