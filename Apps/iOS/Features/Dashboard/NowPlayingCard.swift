import LockyKit
import SwiftUI

/// What the Mac is playing (Music, Spotify, a browser…): artwork, progress, playback controls and
/// the volume of the Mac. The blurred artwork behind, like the wallpaper behind the screens; bright
/// while a track is there, faded while nothing plays.
struct NowPlayingCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        DashboardCard(
            title: titleKey,
            icon: Image(systemName: "music.note"),
            isTitleProminent: model.nowPlaying != nil
        ) {
            if let playing = model.nowPlaying {
                TrackHeader(playing: playing, artwork: model.nowPlayingArtwork)
                // Hidden while the Mac does not know the position (track started before Locky).
                if let duration = playing.duration, duration > 0, playing.elapsed != nil {
                    PlaybackProgress(playing: playing, duration: duration)
                        .disabled(!model.isConnected)
                }
                PlaybackControls(isPlaying: playing.isPlaying, isEnabled: model.isConnected)
            } else {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nothing is playing")
                            .font(.headline)
                            .foregroundStyle(Color.secondary)
                        Text("Play music on your Mac to control it from here.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } icon: {
                    Image(systemName: "music.note.list")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            if let metrics = model.macMetrics, metrics.outputVolume != nil {
                VolumeRow(metrics: metrics, isProminent: model.nowPlaying != nil)
            }
        } backdrop: {
            ArtworkBackdrop(
                artwork: model.nowPlaying == nil ? nil : model.nowPlayingArtwork,
                artworkID: model.nowPlaying?.artworkID,
                isFaded: !model.isConnected
            )
        }
        .animation(.smooth, value: model.nowPlaying?.title)
    }

    private var titleKey: LocalizedStringKey {
        guard let appName = model.nowPlaying?.appName else { return "Now Playing" }
        return "Now Playing in \(appName)"
    }
}

/// Artwork, title and artist.
private struct TrackHeader: View {
    let playing: NowPlaying
    let artwork: Data?

    var body: some View {
        HStack(spacing: 14) {
            TrackArtwork(artwork: artwork, artworkID: playing.artworkID)
                .frame(width: 72, height: 72)
                .clipShape(.rect(cornerRadius: 14))
                .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(playing.title)
                    .font(.headline)
                    .foregroundStyle(Color.primary)
                    .lineLimit(2)
                if let artist = playing.artist {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
                if let album = playing.album, !album.isEmpty {
                    Text(album)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The artwork over its placeholder: a new artwork, or none, fades in 0.2 s.
private struct TrackArtwork: View {
    let artwork: Data?
    let artworkID: String?

    var body: some View {
        ZStack {
            LinearGradient(colors: [.pink, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.title)
                        .foregroundStyle(.white)
                }
            if let image = artwork.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .id(artworkID)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: artwork == nil ? nil : artworkID ?? "")
    }
}

/// Position in the track, advancing on its own between two updates of the Mac. Dragging the bar
/// moves in the track on the Mac.
private struct PlaybackProgress: View {
    @Environment(AppModel.self) private var model
    let playing: NowPlaying
    let duration: TimeInterval
    /// Fraction of the track under the finger, `nil` while not dragging.
    @State private var scrubbed: Double?
    /// Fraction when the finger touched the bar: a tap without moving does not seek.
    @State private var scrubStart: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed: TimeInterval = scrubbed.map { $0 * duration } ?? playing.elapsed(at: context.date) ?? 0
            VStack(spacing: 2) {
                MediaScrubber(
                    value: .init(get: { min(elapsed / duration, 1) }, set: { scrubbed = $0 }),
                    accessibilityLabel: Text("Position in the track")
                ) { isEditing in
                    if isEditing {
                        scrubStart = min(elapsed / duration, 1)
                        return
                    }
                    if let scrubbed, let scrubStart, abs(scrubbed - scrubStart) * duration >= 0.5 {
                        model.sendMediaCommand(.seek(scrubbed * duration))
                    }
                    scrubbed = nil
                    scrubStart = nil
                }
                HStack {
                    Text(Self.time(elapsed))
                    Spacer()
                    Text("-\(Self.time(max(0, duration - elapsed)))")
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(Color.secondary)
                .accessibilityHidden(true)
            }
        }
    }

    private static func time(_ seconds: TimeInterval) -> String {
        let duration: Duration = .seconds(Int(seconds))
        return duration.formatted(.time(pattern: seconds >= 3_600 ? .hourMinuteSecond : .minuteSecond))
    }
}

/// Previous, play/pause, next.
private struct PlaybackControls: View {
    @Environment(AppModel.self) private var model
    let isPlaying: Bool
    let isEnabled: Bool

    var body: some View {
        HStack {
            Spacer()
            Button("Previous track", systemImage: "backward.fill") {
                model.sendMediaCommand(.previousTrack)
            }
            .font(.title2)
            Spacer()
            Button(isPlaying ? "Pause" : "Play", systemImage: isPlaying ? "pause.fill" : "play.fill") {
                model.sendMediaCommand(.playPause)
            }
            .font(.largeTitle)
            .contentTransition(.symbolEffect(.replace))
            Spacer()
            Button("Next track", systemImage: "forward.fill") {
                model.sendMediaCommand(.nextTrack)
            }
            .font(.title2)
            Spacer()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(Color.primary)
        .disabled(!isEnabled)
        .sensoryFeedback(.selection, trigger: isPlaying)
    }
}

/// Volume of the Mac.
private struct VolumeRow: View {
    @Environment(AppModel.self) private var model
    let metrics: MacMetrics
    /// Primary while a track plays, secondary otherwise.
    let isProminent: Bool
    @State private var volume: Double = 0
    @State private var isEditing: Bool = false
    @State private var lastSent: ContinuousClock.Instant?

    var body: some View {
        HStack(spacing: 12) {
            Button(metrics.isMuted ? "Unmute" : "Mute", systemImage: metrics.isMuted ? "speaker.slash.fill" : "speaker.fill") {
                model.sendMediaCommand(.toggleMute)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 24)
            MediaScrubber(value: $volume, accessibilityLabel: Text("Volume of your Mac"), isProminent: isProminent) { editing in
                isEditing = editing
                if !editing {
                    model.sendMediaCommand(.setVolume(volume))
                }
            }
            Image(systemName: "speaker.wave.3.fill")
                .accessibilityHidden(true)
        }
        .font(.subheadline)
        .foregroundStyle(isProminent ? Color.primary : Color.secondary)
        .disabled(!model.isConnected)
        .opacity(metrics.isMuted ? 0.6 : 1)
        .onAppear {
            volume = metrics.outputVolume ?? 0
        }
        .onChange(of: metrics.outputVolume) { _, newVolume in
            if !isEditing, let newVolume {
                volume = newVolume
            }
        }
        .onChange(of: volume) { _, newVolume in
            // Follow the finger without flooding Bluetooth.
            guard isEditing else { return }
            if let lastSent, ContinuousClock.now - lastSent < .milliseconds(150) { return }
            lastSent = .now
            model.sendMediaCommand(.setVolume(newVolume))
        }
    }
}
