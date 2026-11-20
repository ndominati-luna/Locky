import SwiftUI

/// The thief of the original onboarding: the hat drops, the eyes blink, the camera flashes.
struct IntruderIllustration: View {
    @State private var isHatVisible: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let tick: Int = .init(timeline.date.timeIntervalSinceReferenceDate / 0.25) % 14
            ZStack {
                Image(.flash)
                    .resizable()
                    .scaledToFit()
                    .opacity(tick == 9 || tick == 10 ? 1 : 0)
                    .scaleEffect(tick == 9 ? 1.15 : 1)
                Image(.thiefHat)
                    .resizable()
                    .scaledToFit()
                    .offset(y: isHatVisible ? 0 : -120)
                    .opacity(isHatVisible ? 1 : 0)
                Image(.thiefEyes)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(x: 1, y: tick == 4 || tick == 12 ? 0.1 : 1, anchor: .center)
                    .opacity(isHatVisible ? 1 : 0)
            }
            .background {
                // Camera flash lighting up the whole scene.
                Circle()
                    .fill(Color.brandArt.opacity(tick == 9 ? 0.35 : 0))
                    .blur(radius: 40)
            }
            .animation(.easeOut(duration: 0.15), value: tick)
        }
        .foregroundStyle(Color.brandArt)
        .task {
            try? await Task.sleep(for: .milliseconds(200))
            withAnimation(.spring(duration: 0.6, bounce: 0.45)) { isHatVisible = true }
        }
        .accessibilityHidden(true)
    }
}
