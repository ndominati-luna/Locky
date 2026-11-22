import AVFoundation
import SwiftUI

/// The video of the first Locky, found by tapping the logo of About (see ``LockyStory``): the
/// blue and the white drawings of the original Locky, a word about Tom and Nico, and the player
/// in the middle. Stacked in portrait, side by side in landscape, on two pages of an unfolded
/// iPhone Duo (the film on its own page, never across the fold).
struct LockyStoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.screenFold) private var fold
    @State private var playback: StoryPlayback?
    @State private var isWide: Bool = false

    var body: some View {
        NavigationStack {
            Group {
                if let fold {
                    UnfoldedStory(fold: fold, playback: playback)
                } else if isWide {
                    HStack(spacing: 32) {
                        ScrollView {
                            StoryWords(isCompact: true)
                                .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(maxWidth: 360)
                        StoryFilm(playback: playback)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            StoryWords(isCompact: false)
                            StoryFilm(playback: playback)
                            StoryFooter()
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 32)
                        .frame(maxWidth: 560)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height * 1.1 } action: { isWide = $0 }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background {
                RetroBackground()
            }
        }
        // White drawings and text on the Locky blue, whatever the appearance of the iPhone.
        .environment(\.colorScheme, .dark)
        .task {
            let playback: StoryPlayback = .init()
            self.playback = playback
            // Plays even with the ring switch on silent, like any video.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            // Once the screen has slid in.
            try? await Task.sleep(for: .milliseconds(700))
            playback.player.isMuted = false
            playback.player.play()
        }
        .onDisappear {
            playback?.player.pause()
            try? AVAudioSession.sharedInstance().setCategory(.ambient)
        }
    }
}

/// Two pages of an unfolded iPhone Duo: the words on one, the film on the other (on top when the
/// iPhone is half open like a laptop, where the upper page faces you).
private struct UnfoldedStory: View {
    let fold: ScreenFold
    let playback: StoryPlayback?

    var body: some View {
        Group {
            if fold.orientation == .horizontal {
                TwoPageLayout(fold: fold) {
                    StoryFilm(playback: playback)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 8)
                    ScrollView {
                        StoryWords(isCompact: true)
                            .padding(.horizontal, 40)
                            .padding(.vertical, 8)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            } else {
                TwoPageLayout(fold: fold) {
                    ScrollView {
                        VStack(spacing: 28) {
                            StoryWords(isCompact: false)
                            StoryFooter()
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    StoryFilm(playback: playback)
                        .padding(.horizontal, 32)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}

/// The logo of the first Locky, then who made it and how the video was found.
private struct StoryWords: View {
    /// Next to the film: a smaller logo.
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 14 : 20) {
            LockyAssemblyIllustration()
                .frame(height: isCompact ? 90 : 130)
            Text("Since \(String(LockyStory.firstReleaseYear))")
                .font(.footnote.weight(.semibold).monospaced())
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: .capsule)
            Text("A wild ride with Tom and Nico")
                .font(.system(isCompact ? .title : .largeTitle, design: .rounded, weight: .bold))
            Text("You found it! \(LockyStory.tapCount) taps, one for every year since the very first Locky.")
                .font(.headline)
            Text("Back in \(String(LockyStory.firstReleaseYear)), Tom and Nico dreamed of a Mac that locks itself when you walk away. Here is the video from back then.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The player in the middle, framed like a picture of the time.
private struct StoryFilm: View {
    let playback: StoryPlayback?

    var body: some View {
        Group {
            if let playback {
                StoryVideoPlayer(player: playback.player)
            } else {
                Color.black
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(.white.opacity(0.85), lineWidth: 3)
        }
        .shadow(color: .black.opacity(0.35), radius: 22, y: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Footprints walking off, as in the first Locky, and a thank-you.
private struct StoryFooter: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                ForEach(0..<5, id: \.self) { index in
                    Image(index.isMultiple(of: 2) ? .stepLeft : .stepRight)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 22)
                        .offset(y: index.isMultiple(of: 2) ? -6 : 6)
                        .opacity(0.35 + Double(index) * 0.15)
                }
            }
            Text("Thanks for being part of the trip.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

/// The blue of the original Locky, from cyan to deep blue, under twinkling stars.
private struct RetroBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.78, blue: 0.98),
                    Color.lockyBlue,
                    Color(red: 0.04, green: 0.24, blue: 0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            SparklesView()
                .foregroundStyle(.white)
                .opacity(0.5)
                .padding(24)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
