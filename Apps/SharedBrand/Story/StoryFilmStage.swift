import SwiftUI

/// The film on a page of its own (an unfolded iPhone Duo held landscape, the window of the Mac): a
/// title above the display, the footprints of the first Locky walking away under it.
struct StoryFilmStage: View {
    let playback: StoryPlayback?

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text("The \(String(LockyStory.firstYear)) film")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("In July \(String(LockyStory.firstYear)), Locky was still “soon on the App Store”.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
            }
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            // Narrow enough to stay clear of the clock when the page runs under the status bar.
            .frame(maxWidth: 280)
            StoryFilm(playback: playback)
            StoryFootsteps(count: 7, width: 26)
        }
    }
}
