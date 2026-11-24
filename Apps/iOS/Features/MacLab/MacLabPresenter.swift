import SwiftUI
import UIKit

/// The Mac lab, a hidden screen. Shaking the iPhone three times in a row unlocks it, with fireworks;
/// once it has been opened, one shake is enough, and it opens straight away. Its Macs keep their
/// settings apart from those of the home screen.
enum MacLab {
    /// The settings of the Macs of the lab (lid, tilt, keyboard, display), apart from the app's.
    @MainActor static let defaults: UserDefaults = .init(suiteName: "studio.lunabee.locky.maclab") ?? .standard
    /// Set once the lab has been opened: one shake opens it from then on.
    static let openedKey: String = "macLabOpened"
    /// Shakes in a row to unlock it, and the longest pause between two of them.
    static let unlockingShakes: Int = 3
    static let longestPause: TimeInterval = 2
    /// Three fingers held three seconds at the top of the lab, above the Mac, lock it again,
    /// discreetly: the next time, three shakes and the fireworks again.
    static let relockingFingers: Int = 3
    static let relockingDuration: TimeInterval = 3

    static func relock() {
        UserDefaults.standard.removeObject(forKey: openedKey)
    }
}

/// Shows the Mac lab in a window of its own, over everything (a sheet included), and counts the
/// shakes that open it.
@MainActor
final class MacLabPresenter {
    static let shared: MacLabPresenter = .init()

    private var window: UIWindow?
    private weak var previousKeyWindow: UIWindow?
    /// The recent shakes, while the lab is still locked.
    private var shakes: [Date] = []

    /// A shake of the iPhone, the app in the foreground.
    func deviceShook(model: AppModel) {
        guard window == nil else { return }
        if UserDefaults.standard.bool(forKey: MacLab.openedKey) {
            present(model: model, celebrates: false)
            return
        }
        let now: Date = .now
        if let last = shakes.last, now.timeIntervalSince(last) > MacLab.longestPause {
            shakes = []
        }
        shakes.append(now)
        guard shakes.count >= MacLab.unlockingShakes else { return }
        shakes = []
        present(model: model, celebrates: true)
    }

    private func present(model: AppModel, celebrates: Bool) {
        let scenes: [UIWindowScene] = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        previousKeyWindow = scene.keyWindow
        let window: UIWindow = .init(windowScene: scene)
        window.windowLevel = .alert + 1
        window.backgroundColor = .clear
        let host: UIHostingController = .init(
            rootView: MacLabStage(celebrates: celebrates) { [weak self] in
                self?.dismiss()
            }
            .environment(model)
        )
        host.view.backgroundColor = .clear
        window.rootViewController = host
        window.makeKeyAndVisible()
        self.window = window
    }

    private func dismiss() {
        window?.isHidden = true
        window = nil
        previousKeyWindow?.makeKey()
    }
}

/// What the window of the lab shows: the fireworks the first time, then the lab, revealed by a wave
/// that spreads from the middle of the screen, the lab fading in under it; closed, the wave draws
/// back to the middle.
private struct MacLabStage: View {
    let celebrates: Bool
    let finish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showsFireworks: Bool
    /// How far the wave has spread: 0 nothing of the lab, 1 all of it.
    @State private var reveal: Double = 0
    @State private var dim: Double = 0

    init(celebrates: Bool, finish: @escaping () -> Void) {
        self.celebrates = celebrates
        self.finish = finish
        _showsFireworks = State(initialValue: celebrates)
    }

    var body: some View {
        // The margins of the window, read here: the lab covers the whole window, its background
        // under the bars of the system, and keeps its buttons within them.
        GeometryReader { proxy in
            stage(safeArea: proxy.safeAreaInsets)
                .ignoresSafeArea()
        }
        .defaultAppStorage(MacLab.defaults)
        .task {
            if celebrates {
                withAnimation(.easeOut(duration: 0.5)) { dim = 0.72 }
            } else {
                open()
            }
        }
    }

    private func stage(safeArea: EdgeInsets) -> some View {
        ZStack {
            Color.black
                .opacity(dim)
            MacLabView(safeArea: safeArea, close: close)
                .mask {
                    RevealMask(progress: reduceMotion ? 1 : reveal)
                }
                .opacity(reduceMotion ? reveal : min(1, reveal * 1.6))
                .allowsHitTesting(reveal > 0.99)
            if !reduceMotion {
                RevealWave(progress: reveal)
            }
            if showsFireworks {
                LockyFireworks {
                    showsFireworks = false
                    open()
                }
                .transition(.opacity)
            }
        }
    }

    private func open() {
        UserDefaults.standard.set(true, forKey: MacLab.openedKey)
        withAnimation(reduceMotion ? .easeOut(duration: 0.3) : .easeInOut(duration: 0.95)) {
            reveal = 1
            dim = 0.72
        }
    }

    private func close() {
        withAnimation(reduceMotion ? .easeIn(duration: 0.25) : .easeInOut(duration: 0.6)) {
            reveal = 0
            dim = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 280 : 640))
            finish()
        }
    }
}

/// The disc of the wave, opaque in its middle and fading out at its edge, which blends the lab into
/// what lies under it.
private struct RevealMask: View, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let reach: CGFloat = hypot(proxy.size.width, proxy.size.height) / 2 * 1.25
            let edge: Double = min(max(progress, 0), 1)
            RadialGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: max(0, edge - 0.2)),
                    .init(color: .clear, location: max(edge, 0.0001))
                ],
                center: .center,
                startRadius: 0,
                endRadius: reach
            )
        }
    }
}

/// The light at the edge of the wave: a ring that spreads from the middle, thinner and fainter as
/// it goes.
private struct RevealWave: View, Animatable {
    var progress: Double

    nonisolated var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    var body: some View {
        GeometryReader { proxy in
            let reach: CGFloat = hypot(proxy.size.width, proxy.size.height) / 2 * 1.25
            let shown: Double = sin(min(max(progress, 0), 1) * .pi)
            ZStack {
                ForEach(0..<2, id: \.self) { ring in
                    let radius: CGFloat = reach * CGFloat(max(progress - 0.1 - Double(ring) * 0.12, 0))
                    Circle()
                        .stroke(ring == 0 ? Color.white : FireworksShow.sky, lineWidth: CGFloat(10 - ring * 4) * CGFloat(1 - progress) + 2)
                        .frame(width: radius * 2, height: radius * 2)
                        .blur(radius: 6)
                        .opacity(shown * (ring == 0 ? 0.75 : 0.5))
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
