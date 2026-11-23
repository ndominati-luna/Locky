import SwiftUI

/// The end credits of the film, rolling up on black like at the movies, then an invitation to
/// watch it again. Shown at once, without rolling, when motion is reduced.
struct StoryCreditsRoll: View {
    let replay: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var frameHeight: CGFloat = 0
    @State private var creditsHeight: CGFloat = 0
    /// 0: the credits wait below the frame; 1: they have left it at the top.
    @State private var progress: CGFloat = 0
    @State private var isOver: Bool = false

    private static let rollDuration: Double = 16

    var body: some View {
        Color.black
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { frameHeight = $0 }
            .overlay {
                if !isOver {
                    StoryCredits()
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { creditsHeight = $0 }
                        .offset(y: (1 - 2 * progress) * (frameHeight + creditsHeight) / 2)
                        .transition(.opacity)
                }
            }
            .overlay {
                if isOver {
                    StoryEndCard(replay: replay)
                        .transition(.opacity)
                }
            }
            .clipped()
            .task {
                guard !reduceMotion else {
                    isOver = true
                    return
                }
                // Once the black has faded in and the credits are measured.
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.linear(duration: Self.rollDuration)) { progress = 1 }
                try? await Task.sleep(for: .seconds(Self.rollDuration))
                withAnimation(.easeInOut(duration: 0.8)) { isOver = true }
            }
    }
}

/// Who made Locky (Tom and Nico, and no one else), then a wink at the store the film promises.
private struct StoryCredits: View {
    var body: some View {
        VStack(spacing: 22) {
            Text(verbatim: "Locky")
                .font(.system(.title, design: .rounded, weight: .bold))
            VStack(spacing: 4) {
                Text("Dreamed up and made by")
                    .font(.caption2.weight(.semibold))
                    .textCase(.uppercase)
                    .kerning(1.5)
                    .foregroundStyle(.white.opacity(0.6))
                Text("Tom and Nico")
                    .font(.headline)
                Text("at Lunabee Studio")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            Text("Thanks to everyone who has walked away from their Mac since \(String(LockyStory.firstYear)).")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
            // The film ends on a promise the App Store no longer keeps: the iPhone app now goes
            // through TestFlight only.
            Text("The film promised “soon on the App Store”. Locky lived there from 2015 to 2017; this time, it stays between us.")
                .font(.footnote.italic())
                .foregroundStyle(.white.opacity(0.6))
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

/// After the credits: the year it all began and the film again.
private struct StoryEndCard: View {
    let replay: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Since \(String(LockyStory.firstYear))")
                .font(.footnote.weight(.semibold).monospaced())
                .foregroundStyle(.white.opacity(0.75))
            Button("Watch again", systemImage: "arrow.counterclockwise", action: replay)
                .buttonStyle(.glass)
        }
        .foregroundStyle(.white)
    }
}
