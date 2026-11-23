import SwiftUI

/// The video of the first Locky on the Mac, found by clicking the logo of About (see
/// ``LockyStory``): the words, Locky then and now and its timeline on the left, the film (with its
/// end credits) on the right, on the blue of the original Locky.
struct StoryWindowView: View {
    @State private var playback: StoryPlayback?

    var body: some View {
        HStack(spacing: 36) {
            ScrollView {
                VStack(spacing: 28) {
                    StoryWords(isCompact: true)
                    StoryChapters()
                }
                .padding(.vertical, 36)
            }
            .scrollIndicators(.never)
            .scrollBounceBehavior(.basedOnSize)
            .frame(width: 380)
            StoryFilmStage(playback: playback)
                .padding(.vertical, 36)
        }
        .padding(.horizontal, 36)
        .frame(minWidth: 1000, minHeight: 620)
        .background {
            StoryBackground()
        }
        // White drawings and text on the Locky blue, whatever the appearance of the Mac.
        .environment(\.colorScheme, .dark)
        .task {
            // The full screen of the player can take this view away and bring it back, which runs
            // this task again: one film only. It stops when the window closes and lets it go.
            guard playback == nil else { return }
            let playback: StoryPlayback = .init()
            self.playback = playback
            // Once the window is on screen.
            try? await Task.sleep(for: .milliseconds(500))
            playback.start()
        }
    }
}
