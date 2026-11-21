import SwiftUI

/// The lock animation playing in a loop over the wallpaper of the Mac: locking, a pause on the
/// logo, unlocking, a pause on the desktop. It starts again whenever the animation changes. Shown in
/// the animation window of the Mac and in the settings of the iPhone.
public struct LockAnimationPreview: View {
    let animation: LockAnimation
    let backdrop: LockBackdrop
    /// The wallpaper of the Mac: it stands for the desktop.
    let desktop: PlatformImage?
    @State private var phase: TransitionView.Kind?
    @State private var cycle: Int = 0
    @State private var height: CGFloat = 0

    public init(animation: LockAnimation, backdrop: LockBackdrop, desktop: PlatformImage?) {
        self.animation = animation
        self.backdrop = backdrop
        self.desktop = desktop
    }

    public var body: some View {
        ZStack {
            DesktopImage(image: desktop)
            if animation.style == .none {
                NoAnimationPreview(desktop: desktop)
            } else if let phase, height > 0 {
                TransitionView(kind: phase, animation: animation, backdrop: backdrop, desktop: desktop, logoSize: height * 0.24)
                    .id(cycle)
            }
        }
        .clipped()
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
        .task(id: animation) {
            await loop()
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Preview of the lock animation", bundle: .module))
    }

    private func loop() async {
        phase = nil
        guard animation.style != .none else { return }
        try? await Task.sleep(for: .milliseconds(300))
        while !Task.isCancelled {
            phase = .locking
            cycle += 1
            try? await Task.sleep(for: .seconds(animation.lockDuration + 1.4))
            guard !Task.isCancelled else { return }
            phase = .unlocking
            cycle += 1
            try? await Task.sleep(for: .seconds(animation.style.unlockDuration + 0.4))
            guard !Task.isCancelled else { return }
            phase = nil
            try? await Task.sleep(for: .seconds(1.2))
        }
    }
}

/// No animation: the lock screen comes at once.
private struct NoAnimationPreview: View {
    let desktop: PlatformImage?

    var body: some View {
        ZStack {
            DesktopImage(image: desktop)
                .blur(radius: 16, opaque: true)
                .overlay(Color.black.opacity(0.3))
            VStack(spacing: 8) {
                Image(systemName: "lock.fill")
                    .font(.title)
                Text("The lock screen appears at once.", bundle: .module)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding()
        }
    }
}

/// The wallpaper filling the preview, a gradient while it loads.
private struct DesktopImage: View {
    let image: PlatformImage?

    var body: some View {
        LinearGradient(colors: [.indigo, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay {
                if let image {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFill()
                }
            }
            .clipped()
            .accessibilityHidden(true)
    }
}
