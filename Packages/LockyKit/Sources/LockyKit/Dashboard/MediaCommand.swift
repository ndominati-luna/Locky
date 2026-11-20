import Foundation

/// Playback and volume commands sent from the iPhone dashboard to the Mac.
public enum MediaCommand: Codable, Sendable, Equatable {
    case playPause
    case nextTrack
    case previousTrack
    /// From 0 to 1.
    case setVolume(Double)
    case toggleMute
}
