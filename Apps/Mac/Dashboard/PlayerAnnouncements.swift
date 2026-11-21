import AppKit
import Foundation

/// What Music and Spotify announce to every app with distributed notifications: title, artist,
/// album, duration, state, and the position for Spotify. No permission and no polling, unlike
/// AppleScript. Listening starts with Locky, so the track is known when the dashboard opens.
@MainActor
final class PlayerAnnouncements {
    private struct Announced {
        let identity: String
        var track: PlayerTrack
    }

    private var announced: [ScriptablePlayer: Announced] = [:]
    /// Players that announced something since Locky started (a stop included).
    private var heard: Set<ScriptablePlayer> = []
    private var observers: [any NSObjectProtocol] = []
    /// A player announced a change.
    var onChange: (() -> Void)?

    init() {
        let center: DistributedNotificationCenter = .default()
        for player in ScriptablePlayer.allCases {
            let observer: any NSObjectProtocol = center.addObserver(forName: .init(player.announcementName), object: nil, queue: .main) { [weak self] notification in
                let announcement: PlayerAnnouncement? = .init(notification.userInfo)
                MainActor.assumeIsolated {
                    self?.received(announcement, from: player)
                }
            }
            observers.append(observer)
        }
    }

    /// Whether a player announced something since Locky started.
    var hasAnnouncements: Bool {
        !announced.isEmpty
    }

    /// The track playing, otherwise the paused one, among the players still running.
    var current: PlayerTrack? {
        let tracks: [PlayerTrack] = ScriptablePlayer.allCases.compactMap { player in
            player.isRunning ? announced[player]?.track : nil
        }
        return tracks.first { $0.isPlaying } ?? tracks.first
    }

    /// The actual position of the track, read with AppleScript.
    func correct(_ player: ScriptablePlayer, trackKey: String, elapsed: TimeInterval, at date: Date) {
        guard var current = announced[player], current.track.key == trackKey else { return }
        current.track.elapsed = elapsed
        current.track.elapsedDate = date
        announced[player] = current
    }

    private func received(_ announcement: PlayerAnnouncement?, from player: ScriptablePlayer) {
        guard let announcement else { return }
        defer {
            heard.insert(player)
            onChange?()
        }
        guard announcement.state != .stopped else {
            announced[player] = nil
            return
        }
        let now: Date = .now
        let isPlaying: Bool = announcement.state == .playing
        let elapsed: TimeInterval? = if let position = announcement.position {
            position
        } else if let previous = announced[player], previous.identity == announcement.identity {
            // Pause or resume of the same track: it advanced while it played.
            previous.track.elapsed(at: now)
        } else if heard.contains(player), isPlaying {
            // Music announces a track change as it happens: the new track starts from the beginning.
            0
        } else {
            // First announcement since Locky started (resume in the middle of a track…): unknown,
            // until AppleScript tells it with the artwork.
            nil
        }
        announced[player] = .init(
            identity: announcement.identity,
            track: .init(
                title: announcement.title,
                artist: announcement.artist,
                album: announcement.album,
                appName: player.localizedName,
                isPlaying: isPlaying,
                duration: announcement.duration,
                elapsed: elapsed,
                elapsedDate: now,
                artwork: .script(player)
            )
        )
    }
}
