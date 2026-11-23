import AVFoundation
import SwiftUI

/// The video of the first Locky, found by tapping the logo of About (see ``LockyStory``): the
/// blue and the white drawings of the original Locky, a word about Tom and Nico, the player (with
/// its end credits), then Locky in 2015 and in 2026 and its timeline. Stacked in portrait, side by
/// side in landscape, on two pages of an unfolded iPhone Duo (the film on its own page, never
/// across the fold).
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
                            VStack(spacing: 28) {
                                StoryWords(isCompact: true)
                                StoryChapters()
                            }
                            .padding(.vertical, 12)
                        }
                        .scrollIndicators(.hidden)
                        .scrollBounceBehavior(.basedOnSize)
                        .frame(maxWidth: 380)
                        StoryFilm(playback: playback)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            StoryWords(isCompact: false)
                            StoryFilm(playback: playback)
                            StoryChapters()
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
                    Button(role: .close, action: close)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background {
                StoryBackground()
            }
        }
        // White drawings and text on the Locky blue, whatever the appearance of the iPhone.
        .environment(\.colorScheme, .dark)
        .task {
            // The full screen of the player takes this screen away and brings it back, which runs
            // this task again: one film only, and it keeps its sound.
            guard playback == nil else { return }
            let playback: StoryPlayback = .init()
            self.playback = playback
            // Plays even with the ring switch on silent, like any video.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            // Once the screen has slid in.
            try? await Task.sleep(for: .milliseconds(700))
            playback.start()
        }
    }

    /// The only way out of the story: the film stops and the sound goes back to the app's.
    private func close() {
        playback?.player.pause()
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        dismiss()
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
                        VStack(spacing: 28) {
                            StoryWords(isCompact: true)
                            StoryChapters()
                                .frame(maxWidth: 560)
                        }
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
                            StoryChapters()
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    // A whole page for the film: the display as large as it fits, decorated, up to
                    // the edge of the screen (under the clock and the close button, the column
                    // of the status bar is empty).
                    StoryFilmStage(playback: playback)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 20)
                        .ignoresSafeArea(.container, edges: .trailing)
                }
            }
        }
        .scrollIndicators(.hidden)
    }
}
