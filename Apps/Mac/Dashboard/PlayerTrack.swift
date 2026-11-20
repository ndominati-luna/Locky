import Foundation

/// A track read from MediaRemote or from a scriptable player, before its artwork is prepared.
struct PlayerTrack: Sendable {
    enum Artwork: Sendable {
        case data(Data)
        case url(URL)
        /// Asked to the player with AppleScript, only when the track changes.
        case script(ScriptablePlayer)
    }

    var title: String
    var artist: String?
    var album: String?
    var appName: String?
    var isPlaying: Bool
    var duration: TimeInterval?
    var elapsed: TimeInterval?
    var elapsedDate: Date
    var artwork: Artwork?

    /// Position at `date`, advancing while playing.
    func elapsed(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        let position: TimeInterval = isPlaying ? elapsed + date.timeIntervalSince(elapsedDate) : elapsed
        return duration.map { min(position, $0) } ?? position
    }

    /// Identifies the track (and therefore its artwork).
    var key: String {
        [title, artist ?? "", album ?? "", appName ?? ""].joined(separator: "\u{1F}")
    }
}
