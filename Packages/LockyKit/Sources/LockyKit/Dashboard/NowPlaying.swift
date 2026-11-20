import Foundation

/// What the Mac is playing (Music, Spotify, a browser…), shown and controlled from the dashboard of
/// the iPhone.
public struct NowPlaying: Codable, Sendable, Equatable {
    public var title: String
    public var artist: String?
    public var album: String?
    /// Name of the playing app ("Music", "Spotify"…).
    public var appName: String?
    public var isPlaying: Bool
    public var duration: TimeInterval?
    /// Position at ``elapsedDate``.
    public var elapsed: TimeInterval?
    public var elapsedDate: Date
    /// Changes with the artwork. The artwork itself goes through iCloud, never over Bluetooth.
    public var artworkID: String?
    /// Small HEIC image, only on the device that read it: it is not encoded (see ``CodingKeys``),
    /// the Mac uploads it to iCloud and the iPhone fetches it there.
    public var artwork: Data?

    private enum CodingKeys: String, CodingKey {
        case title, artist, album, appName, isPlaying, duration, elapsed, elapsedDate, artworkID
    }

    public init(
        title: String,
        artist: String?,
        album: String?,
        appName: String?,
        isPlaying: Bool,
        duration: TimeInterval?,
        elapsed: TimeInterval?,
        elapsedDate: Date,
        artworkID: String?,
        artwork: Data?
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.appName = appName
        self.isPlaying = isPlaying
        self.duration = duration
        self.elapsed = elapsed
        self.elapsedDate = elapsedDate
        self.artworkID = artworkID
        self.artwork = artwork
    }

    /// Position at `date`, advancing while playing.
    public func elapsed(at date: Date) -> TimeInterval? {
        guard let elapsed else { return nil }
        let position: TimeInterval = isPlaying ? elapsed + date.timeIntervalSince(elapsedDate) : elapsed
        guard let duration else { return max(0, position) }
        return min(max(0, position), duration)
    }

    /// Same track and state, ignoring the artwork bytes and a regular progression of the position.
    public func isSameState(as other: NowPlaying) -> Bool {
        guard
            title == other.title, artist == other.artist, album == other.album, appName == other.appName,
            isPlaying == other.isPlaying, duration == other.duration, artworkID == other.artworkID
        else { return false }
        let now: Date = .now
        guard let mine = elapsed(at: now), let theirs = other.elapsed(at: now) else { return elapsed == other.elapsed }
        return abs(mine - theirs) < 2
    }
}
