import SwiftUI

/// The player in the middle, framed like a picture of the time. When the film is over, the end
/// credits roll over it, then it can be watched again.
struct StoryFilm: View {
    let playback: StoryPlayback?

    var body: some View {
        ZStack {
            if let playback {
                StoryVideoPlayer(player: playback.player)
                if playback.hasEnded {
                    StoryCreditsRoll(replay: playback.replay)
                        .transition(.opacity)
                }
            } else {
                Color.black
            }
        }
        .animation(.easeInOut(duration: 0.6), value: playback?.hasEnded)
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
