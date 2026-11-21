import Foundation

/// Playback and volume commands sent from the iPhone dashboard to the Mac.
public enum MediaCommand: Codable, Sendable, Equatable {
    case playPause
    case nextTrack
    case previousTrack
    /// Moves to this position in the track, in seconds.
    case seek(TimeInterval)
    /// From 0 to 1.
    case setVolume(Double)
    case toggleMute
}
