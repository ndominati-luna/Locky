import Foundation

/// A distributed notification of Music or Spotify: the state of their player, sent to every app on
/// each change (track, play, pause, stop).
struct PlayerAnnouncement: Sendable {
    enum State: Sendable {
        case playing
        case paused
        case stopped
    }

    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval?
    /// Position at the time of the notification (Spotify only).
    let position: TimeInterval?
    let state: State
    /// Identifies the track, to tell a pause from a new track.
    let identity: String

    init?(_ userInfo: [AnyHashable: Any]?) {
        guard let userInfo else { return nil }
        let state: State = switch userInfo["Player State"] as? String {
        case "Playing": .playing
        case "Paused": .paused
        default: .stopped
        }
        let title: String = userInfo["Name"] as? String ?? ""
        guard state == .stopped || !title.isEmpty else { return nil }
        self.state = state
        self.title = title
        artist = (userInfo["Artist"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        album = (userInfo["Album"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        // Milliseconds: "Total Time" for Music, "Duration" for Spotify.
        duration = ((userInfo["Total Time"] ?? userInfo["Duration"]) as? NSNumber).map { $0.doubleValue / 1_000 }
        position = (userInfo["Playback Position"] as? NSNumber)?.doubleValue
        let identifier: Any? = userInfo["PersistentID"] ?? userInfo["Persistent ID"] ?? userInfo["Track ID"]
        identity = identifier.map { String(describing: $0) } ?? [title, artist ?? "", album ?? ""].joined(separator: "\u{1F}")
    }
}
