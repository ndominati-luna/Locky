import SwiftUI

/// The film on a Pro Display XDR, handled with the hands like the real one (see
/// ``ProDisplayXDR``), over the picture too. When the film is over, the end credits roll on the
/// display, then it can be watched again.
struct StoryFilm: View {
    let playback: StoryPlayback?
    @State private var pose: ProDisplayXDRPose = .init()

    var body: some View {
        ProDisplayXDR(pose: $pose) {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
