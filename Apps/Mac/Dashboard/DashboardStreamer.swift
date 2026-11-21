import Foundation
import LockyKit

/// Streams the state of the Mac to the dashboard of the iPhone (unfolded iPhone Duo), only while
/// it is on screen, over Bluetooth: metrics every 2 seconds, what is playing as soon as it changes
/// (the players announce their changes). Only the artwork goes through iCloud, once per artwork:
/// the iPhone fetches it when the track names it.
@MainActor
final class DashboardStreamer {
    /// Sends a message to the iPhone; `false` when the session is closed.
    var send: ((LockyMessage) -> Bool)?
    /// Uploads an artwork to iCloud; `false` when it failed.
    var publishArtwork: ((_ artworkID: String, _ image: Data) async -> Bool)?

    private var sampler: MacMetricsSampler = .init()
    private let player: NowPlayingReader = .init()
    private var loop: Task<Void, Never>?
    /// Last state sent to the iPhone (`.some(nil)`: nothing playing).
    private var sentNowPlaying: NowPlaying??
    /// Artwork already in iCloud, and the one being uploaded.
    private var uploadedArtworkID: String?
    private var uploadingArtworkID: String?
    /// The player is being read; a change announced meanwhile reads it again right after.
    private var isReadingPlayer: Bool = false
    private var needsReadingPlayer: Bool = false

    init() {
        player.onChange = { [weak self] in
            Task { await self?.refreshNowPlaying() }
        }
    }

    private var isStreaming: Bool {
        loop != nil
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            start()
        } else {
            stop()
        }
    }

    func stop() {
        loop?.cancel()
        loop = nil
    }

    /// Runs a command from the dashboard, then reports the effect of a playback command right away.
    func perform(_ command: MediaCommand) {
        Task {
            await player.perform(command)
            switch command {
            case .setVolume, .toggleMute:
                // The iPhone already shows the new volume, and the slider sends many commands:
                // reading the player at each one would run AppleScript as often. The next refresh
                // confirms it.
                return
            case .playPause, .nextTrack, .previousTrack, .seek:
                break
            }
            try? await Task.sleep(for: .milliseconds(300))
            await player.readPosition()
            await refreshNowPlaying()
        }
    }

    #if DEBUG
    /// Demo: prints the messages instead of sending them (`-LockyDemoDashboardLog YES`).
    func startLogging() {
        let encoder: JSONEncoder = .init()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        // Unbuffered: the demo is usually stopped with a signal.
        let print: (String) -> Void = { FileHandle.standardOutput.write(Data(($0 + "\n").utf8)) }
        send = { message in
            print((try? encoder.encode(message)).flatMap { String(data: $0, encoding: .utf8) } ?? "?")
            return true
        }
        publishArtwork = { artworkID, image in
            print("iCloud artwork \(artworkID): \(image.count) bytes")
            return true
        }
        start()
    }
    #endif

    private func start() {
        stop()
        // The iPhone just opened its dashboard: send again what is playing.
        sentNowPlaying = nil
        // Primes the processor load, computed between two samples.
        _ = sampler.sample()
        loop = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            var round: Int = 0
            while !Task.isCancelled {
                // Every 10 seconds, the actual position: a move in the track made on the Mac is
                // announced by no player.
                if round.isMultiple(of: 5) {
                    await self?.player.readPosition()
                }
                await self?.refresh()
                round += 1
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func refresh() async {
        guard let send, send(.macMetrics(sampler.sample())) else { return }
        await refreshNowPlaying()
    }

    /// Reads the player and sends what is playing when it changed.
    private func refreshNowPlaying() async {
        guard isStreaming else { return }
        guard !isReadingPlayer else {
            needsReadingPlayer = true
            return
        }
        isReadingPlayer = true
        repeat {
            needsReadingPlayer = false
            sendNowPlaying(await player.current())
        } while needsReadingPlayer && isStreaming
        isReadingPlayer = false
    }

    private func sendNowPlaying(_ current: NowPlaying?) {
        var playing: NowPlaying? = current
        if let artworkID = playing?.artworkID, artworkID != uploadedArtworkID {
            // Named once in iCloud, when the iPhone can fetch it.
            upload(artworkID: artworkID, image: playing?.artwork)
            playing?.artworkID = nil
        }
        playing?.artwork = nil
        if let sentNowPlaying {
            switch (sentNowPlaying, playing) {
            case (nil, nil): return
            case let (sent?, now?) where sent.isSameState(as: now): return
            default: break
            }
        }
        guard let send, send(.nowPlaying(playing)) else { return }
        sentNowPlaying = .some(playing)
    }

    private func upload(artworkID: String, image: Data?) {
        guard let image, let publishArtwork, uploadingArtworkID != artworkID else { return }
        uploadingArtworkID = artworkID
        Task {
            let uploaded: Bool = await publishArtwork(artworkID, image)
            if uploadingArtworkID == artworkID {
                uploadingArtworkID = nil
            }
            // Failed: tried again at the next reading.
            guard uploaded else { return }
            uploadedArtworkID = artworkID
            await refreshNowPlaying()
        }
    }
}
