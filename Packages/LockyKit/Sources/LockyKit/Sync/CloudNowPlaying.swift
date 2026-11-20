import Foundation

/// What the Mac is playing, as stored in iCloud.
public struct CloudNowPlaying: Sendable, Equatable {
    /// Changes at every publication of the Mac.
    public var revision: String
    /// `nil` when nothing is playing.
    public var playing: NowPlaying?
    public var artworkID: String?
    /// Only downloaded when the iPhone does not have it yet.
    public var artwork: Data?

    public init(revision: String, playing: NowPlaying?, artworkID: String?, artwork: Data?) {
        self.revision = revision
        self.playing = playing
        self.artworkID = artworkID
        self.artwork = artwork
    }
}
