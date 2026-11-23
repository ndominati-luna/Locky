import AVKit
import SwiftUI

/// The system player, inline, with its floating controls: play, scrub, volume, full screen.
struct StoryVideoPlayer: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> StoryPlayerView {
        let view: StoryPlayerView = .init()
        view.player = player
        view.controlsStyle = .floating
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = true
        // A 30 s film does not need to float above other windows.
        view.allowsPictureInPicturePlayback = false
        return view
    }

    func updateNSView(_ view: StoryPlayerView, context: Context) {
        if view.player !== player {
            view.player = player
        }
    }
}

/// The player, which keeps its clicks: a double click on the film puts the Pro Display XDR back
/// (see ``ProDisplayXDRGestures``) instead of zooming the window, as a double click on a part of
/// the window that moves it would.
final class StoryPlayerView: AVPlayerView {
    override var mouseDownCanMoveWindow: Bool {
        false
    }
}
