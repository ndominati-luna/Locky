import SwiftUI

/// The Locky logo assembling itself: wings spread, the padlock drops in, stars twinkle.
struct LockyAssemblyIllustration: View {
    @State private var areWingsVisible: Bool = false
    @State private var isLockVisible: Bool = false

    var body: some View {
        ZStack {
            SparklesView(isActive: isLockVisible)
                .opacity(isLockVisible ? 1 : 0)
            Image(.lockyWings)
                .resizable()
                .scaledToFit()
                .scaleEffect(x: areWingsVisible ? 1 : 0.2, y: areWingsVisible ? 1 : 0.6)
                .opacity(areWingsVisible ? 1 : 0)
            Image(.lockyLock)
                .resizable()
                .scaledToFit()
                .offset(y: isLockVisible ? 0 : -140)
                .opacity(isLockVisible ? 1 : 0)
        }
        .foregroundStyle(Color.brandArt)
        .task {
            withAnimation(.spring(duration: 0.7, bounce: 0.35)) { areWingsVisible = true }
            try? await Task.sleep(for: .milliseconds(450))
            withAnimation(.spring(duration: 0.6, bounce: 0.5)) { isLockVisible = true }
        }
        .accessibilityHidden(true)
    }
}
