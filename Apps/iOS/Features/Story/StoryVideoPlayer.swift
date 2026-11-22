import AVKit
import SwiftUI

/// The system player, inline, with its controls: play, scrub, volume, full screen.
struct StoryVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller: AVPlayerViewController = .init()
        controller.player = player
        controller.videoGravity = .resizeAspect
        controller.entersFullScreenWhenPlaybackBegins = false
        // Leaving full screen at the end also dismissed the screen of the story, inline: the end
        // credits wait for the viewer to leave full screen instead.
        controller.exitsFullScreenWhenPlaybackEnds = false
        // Picture in picture would need audio in background: a 30 s film does not.
        controller.allowsPictureInPicturePlayback = false
        controller.view.backgroundColor = .black
        return controller
    }

    func updateUIViewController(_ controller: AVPlayerViewController, context: Context) {
        if controller.player !== player {
            controller.player = player
        }
    }
}
