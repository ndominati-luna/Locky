import AVFoundation
import Foundation
import LockyKit

/// Plays the lock sound theme while the app is in foreground.
@MainActor
final class SoundPlayer {
    private var player: AVAudioPlayer?

    func play(_ theme: SoundTheme) {
        guard let fileName = theme.fileName, let url = Bundle.main.url(forResource: fileName, withExtension: "caf") else {
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
