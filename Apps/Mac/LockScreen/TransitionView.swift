import SwiftUI

/// Full screen animation played while locking and unlocking.
///
/// Locking: the desktop fades into the wallpaper; an iris closes on the ring of the Locky logo,
/// drawing the wallpaper in; the wings unfold around the last bubble, the padlock drops and
/// swallows it, then the title appears. Unlocking plays it backwards: the bubble reopens from the
/// ring and the iris widens to the whole screen while the logo vanishes.
struct TransitionView: View {
    enum Kind {
        case locking
        case unlocking
    }

    let kind: Kind
    let desktop: NSImage?
    let title: String
    let logoSize: CGFloat

    @State private var size: CGSize = .zero
    /// Locking starts transparent: the real desktop, windows included, shows through, then fades
    /// into the wallpaper (no screen capture needed).
    @State private var coverOpacity: Double
    /// 0: the iris is open on the whole screen, 1: closed on the ring of the logo.
    @State private var iris: Double
    /// The bubble of wallpaper left in the ring: 1 shown, 0 swallowed by the padlock.
    @State private var bubble: Double
    @State private var showsLogo: Bool
    /// Unlocking: 0 the logo is shown, 1 it has vanished.
    @State private var logoExit: Double = 0

    init(kind: Kind, desktop: NSImage?, title: String, logoSize: CGFloat) {
        self.kind = kind
        self.desktop = desktop
        self.title = title
        self.logoSize = logoSize
        _coverOpacity = .init(initialValue: kind == .locking ? 0 : 1)
        _iris = .init(initialValue: kind == .locking ? 0 : 1)
        _bubble = .init(initialValue: kind == .locking ? 1 : 0)
        _showsLogo = .init(initialValue: kind == .unlocking)
    }

    var body: some View {
        ZStack {
            Color.black
            IrisLayer(
                image: desktop,
                size: size,
                center: irisCenter,
                ringDiameter: 2 * (LockyWing.curlRadius * logoSize - 4),
                iris: iris,
                bubble: bubble
            )
            if showsLogo {
                AnimatedLockyLogo(title: title, size: logoSize, animated: kind == .locking)
                    .scaleEffect(1 + 0.35 * logoExit)
                    .opacity(1 - logoExit)
                    .blur(radius: 10 * logoExit)
                    .transition(.opacity)
            }
        }
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

    private func playLocking() async {
        withAnimation(.easeInOut(duration: TransitionController.fadeDuration)) {
            coverOpacity = 1
        }
        try? await Task.sleep(for: .seconds(TransitionController.fadeDuration))
        withAnimation(.easeInOut(duration: TransitionController.irisDuration)) {
            iris = 1
        }
        // The wings unfold around the bubble as it reaches the ring.
        try? await Task.sleep(for: .seconds(TransitionController.irisDuration * 0.7))
        withAnimation(.easeOut(duration: 0.3)) {
            showsLogo = true
        }
        // The padlock lands in the ring and swallows the last bubble of wallpaper.
        try? await Task.sleep(for: .seconds(0.75))
        withAnimation(.easeIn(duration: 0.3)) {
            bubble = 0
        }
    }

    private func playUnlocking() async {
        try? await Task.sleep(for: .milliseconds(250))
        withAnimation(.easeOut(duration: 0.25)) {
            bubble = 1
        }
        withAnimation(.easeIn(duration: 0.6)) {
            logoExit = 1
        }
        try? await Task.sleep(for: .milliseconds(150))
        withAnimation(.easeInOut(duration: 0.9)) {
            iris = 0
        }
    }

    // MARK: - Geometry

    /// Center of the ring between the curls of the wings: the logo is centered on the screen.
    private var irisCenter: CGPoint {
        .init(x: size.width / 2, y: size.height / 2 + (LockyWing.curlCenter.y - 0.5) * logoSize)
    }
}
