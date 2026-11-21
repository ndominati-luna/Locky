import AppKit
import CryptoKit
import Foundation
import ImageIO
import LockyKit
import OSLog

/// What the Mac is playing, and the playback commands.
///
/// 1. MediaRemote (private, loaded with `dlsym`): every player, artwork included. Recent macOS
///    versions return nothing to apps that are not Apple's: then
/// 2. the distributed notifications of Music and Spotify (no permission, no polling);
/// 3. AppleScript only for the artwork, and to read the state of a player that announced nothing
///    yet (playing since before Locky started): macOS asks once to let Locky control it, never
///    again once refused. Music has no artwork for a streamed track that is not in the library:
///    the Apple Music catalog gives it (``CatalogArtwork``).
///
/// Commands go through the media keys (any player), or MediaRemote without Accessibility.
@MainActor
final class NowPlayingReader {
    private typealias GetInfoFunction = @convention(c) (DispatchQueue, @escaping @convention(block) (CFDictionary?) -> Void) -> Void
    private typealias GetPIDFunction = @convention(c) (DispatchQueue, @escaping @convention(block) (Int32) -> Void) -> Void
    private typealias SendCommandFunction = @convention(c) (UInt32, CFDictionary?) -> Bool

    private static let mediaRemote: String = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    private static let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "NowPlaying")
    private let getInfo: GetInfoFunction? = PrivateSymbols.load("MRMediaRemoteGetNowPlayingInfo", from: mediaRemote, as: GetInfoFunction.self)
    private let getPID: GetPIDFunction? = PrivateSymbols.load("MRMediaRemoteGetNowPlayingApplicationPID", from: mediaRemote, as: GetPIDFunction.self)
    private let sendCommand: SendCommandFunction? = PrivateSymbols.load("MRMediaRemoteSendCommand", from: mediaRemote, as: SendCommandFunction.self)
    /// Artwork prepared for the current track.
    private var artwork: (trackKey: String, id: String?, data: Data?)?
    private var artworkTask: Task<Void, Never>?
    private let announcements: PlayerAnnouncements = .init()
    /// Last track read: the one to move in, whose position to read again.
    private var lastTrack: PlayerTrack?
    /// A player announced a change, or the artwork of the track is ready: read again now.
    var onChange: (() -> Void)?

    init() {
        announcements.onChange = { [weak self] in self?.onChange?() }
    }

    func current() async -> NowPlaying? {
        var track: PlayerTrack? = await mediaRemoteTrack()
        if track == nil {
            track = announcements.current
        }
        if track == nil, !announcements.hasAnnouncements {
            // Playing since before Locky started: ask the players with AppleScript.
            track = await scriptedTrack()
        }
        lastTrack = track
        guard let track else { return nil }
        let prepared: (id: String?, data: Data?)? = preparedArtwork(for: track)
        return .init(
            title: track.title,
            artist: track.artist,
            album: track.album,
            appName: track.appName,
            isPlaying: track.isPlaying,
            duration: track.duration,
            elapsed: track.elapsed,
            elapsedDate: track.elapsedDate,
            artworkID: prepared?.id,
            artwork: prepared?.data
        )
    }

    func perform(_ command: MediaCommand) async {
        switch command {
        case .playPause: press(.playPause, mediaRemoteCommand: 2)
        case .nextTrack: press(.next, mediaRemoteCommand: 4)
        case .previousTrack: press(.previous, mediaRemoteCommand: 5)
        case let .seek(position): await seek(to: position)
        case let .setVolume(volume): SystemVolume.setVolume(volume)
        case .toggleMute: SystemVolume.toggleMute()
        }
    }

    /// Reads the position again after a playback command: Music announces neither a move in the
    /// track nor a return to its start (Previous), and the position would keep running from the
    /// old one.
    func readPosition() async {
        guard let track = lastTrack, let player = track.scriptablePlayer, player.isRunning, !player.isAutomationDenied else { return }
        let date: Date = .now
        guard let output = await Self.runAppleScript(player.positionScript), let milliseconds = Double(output) else { return }
        announcements.correct(player, trackKey: track.key, elapsed: milliseconds / 1_000, at: date)
    }

    /// Moves in the track with AppleScript (Music, Spotify): no media key does it.
    private func seek(to position: TimeInterval) async {
        guard let track = lastTrack, let player = track.scriptablePlayer, player.isRunning, !player.isAutomationDenied else { return }
        guard await Self.runAppleScript(player.seekScript(to: position)) != nil else { return }
        announcements.correct(player, trackKey: track.key, elapsed: position, at: .now)
    }

    private func press(_ key: MediaKeys.Key, mediaRemoteCommand: UInt32) {
        if AccessibilityPermission.isGranted {
            MediaKeys.press(key)
        } else if let sendCommand {
            _ = sendCommand(mediaRemoteCommand, nil)
        }
    }

    // MARK: - MediaRemote

    private func mediaRemoteTrack() async -> PlayerTrack? {
        guard let getInfo else { return nil }
        let fields: MediaRemoteFields? = await withCheckedContinuation { continuation in
            let once: OneShotContinuation<MediaRemoteFields?> = .init(continuation)
            // MediaRemote calls back on the queue it is given.
            getInfo(DispatchQueue.main) { info in
                once.resume(returning: MediaRemoteFields(info as? [String: Any]))
            }
            Task {
                try? await Task.sleep(for: .seconds(1))
                once.resume(returning: nil)
            }
        }
        guard let fields else { return nil }
        return .init(
            title: fields.title,
            artist: fields.artist,
            album: fields.album,
            appName: await playingAppName(),
            isPlaying: (fields.rate ?? 0) > 0,
            duration: fields.duration,
            elapsed: fields.elapsed,
            elapsedDate: fields.timestamp ?? .now,
            artwork: fields.artwork.map { .data($0) }
        )
    }

    private func playingAppName() async -> String? {
        guard let getPID else { return nil }
        let pid: Int32 = await withCheckedContinuation { continuation in
            let once: OneShotContinuation<Int32> = .init(continuation)
            getPID(DispatchQueue.main) { pid in
                once.resume(returning: pid)
            }
            Task {
                try? await Task.sleep(for: .seconds(1))
                once.resume(returning: 0)
            }
        }
        return pid > 0 ? NSRunningApplication(processIdentifier: pid)?.localizedName : nil
    }

    // MARK: - AppleScript (Music, Spotify)

    private func scriptedTrack() async -> PlayerTrack? {
        var paused: PlayerTrack?
        for player in ScriptablePlayer.allCases where player.isRunning && !player.isAutomationDenied {
            guard let output = await Self.runAppleScript(player.trackScript), let track = player.track(from: output) else { continue }
            if track.isPlaying {
                return track
            }
            paused = paused ?? track
        }
        return paused
    }

    // MARK: - Artwork

    /// The artwork of the track when ready; prepares it in the background when the track changes.
    private func preparedArtwork(for track: PlayerTrack) -> (id: String?, data: Data?)? {
        if let artwork, artwork.trackKey == track.key {
            return (artwork.id, artwork.data)
        }
        let key: String = track.key
        artwork = (key, nil, nil)
        artworkTask?.cancel()
        guard let source = track.artwork else { return nil }
        artworkTask = Task { [weak self] in
            let image: Data? = await self?.artworkImage(of: track, from: source)
            guard !Task.isCancelled, let self, self.artwork?.trackKey == key else { return }
            guard let encoded = image.flatMap(Self.encodeArtwork) else {
                Self.logger.notice("No artwork for the track")
                return
            }
            let id: String = SHA256.hash(data: encoded).prefix(8).map { String(format: "%02x", $0) }.joined()
            self.artwork = (key, id, encoded)
            self.onChange?()
        }
        return nil
    }

    /// The artwork of `track`: from the player, otherwise from the Apple Music catalog when Music
    /// streams a track that is not in the library (AppleScript then gives no artwork at all).
    private func artworkImage(of track: PlayerTrack, from source: PlayerTrack.Artwork) async -> Data? {
        switch source {
        case let .data(data):
            return data
        case let .url(url):
            return try? await URLSession.shared.data(from: url).0
        case let .script(player):
            for delay in Self.scriptAttemptDelays {
                try? await Task.sleep(for: delay)
                guard !Task.isCancelled else { return nil }
                // Not yet the announced track (or the script failed): read again.
                guard let reading = await Self.scriptedArtwork(of: player, title: track.title) else { continue }
                guard !Task.isCancelled else { return nil }
                if let position = reading.position {
                    announcements.correct(player, trackKey: track.key, elapsed: position, at: reading.date)
                }
                if let image = reading.image {
                    return image
                }
                guard player == .music else { return nil }
                Self.logger.info("Music has no artwork for the track: asking the Apple Music catalog")
                return await CatalogArtwork.fetch(
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    pixelSize: Self.artworkPixelSize
                )
            }
            return nil
        }
    }

    /// Before each reading with AppleScript: right after announcing a track, the player may still
    /// answer with the previous one.
    private static let scriptAttemptDelays: [Duration] = [.zero, .milliseconds(500), .seconds(1), .seconds(2)]

    /// The artwork of the current track of `player` (none for a streamed track of Music), and the
    /// position in it. `nil` when the player still plays another track than `title`, or when the
    /// script failed.
    private static func scriptedArtwork(of player: ScriptablePlayer, title: String) async -> (image: Data?, position: TimeInterval?, date: Date)? {
        // A file per reading: a cancelled one may still be writing its own. macOS asks once for the
        // permission to control the player.
        let file: URL = URL.temporaryDirectory.appending(path: "locky-artwork-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: file) }
        let date: Date = .now
        guard let output = await runAppleScript(player.artworkScript(writingTo: file)) else {
            logger.info("The artwork script failed")
            return nil
        }
        let fields: [String] = output.components(separatedBy: "\u{1F}")
        guard fields.count >= 3, fields[2] == title else {
            logger.info("The player still plays another track")
            return nil
        }
        let position: TimeInterval? = Double(fields[0]).map { $0 / 1_000 }
        if let url = URL(string: fields[1]), url.scheme == "https" {
            return (try? await URLSession.shared.data(from: url).0, position, date)
        }
        return (try? Data(contentsOf: file), position, date)
    }

    /// Side of the artwork, in pixels: the iPhone shows it 72 points wide, at 3 pixels per point.
    private static let artworkPixelSize: Int = 216

    /// Small JPEG at the size the iPhone shows it: it goes through iCloud at every new artwork.
    private static func encodeArtwork(_ data: Data) -> Data? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: artworkPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
        else { return nil }
        return MacImageRenderer.encode(image, maxPixelSize: artworkPixelSize, opaque: true)
    }

    /// Runs a script with `osascript`, off the main thread (the permission prompt may wait for the
    /// user). Returns its output, `nil` on error.
    @concurrent
    private nonisolated static func runAppleScript(_ source: String) async -> String? {
        await withCheckedContinuation { continuation in
            let process: Process = .init()
            process.executableURL = URL(filePath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            let output: Pipe = .init()
            process.standardOutput = output
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { finished in
                let data: Data = output.fileHandleForReading.readDataToEndOfFile()
                let text: String? = finished.terminationStatus == 0 ? String(data: data, encoding: .utf8) : nil
                continuation.resume(returning: text?.trimmingCharacters(in: .newlines))
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }
}

/// Fields of the MediaRemote now playing dictionary.
private struct MediaRemoteFields: Sendable {
    let title: String
    let artist: String?
    let album: String?
    let duration: TimeInterval?
    let elapsed: TimeInterval?
    let rate: Double?
    let timestamp: Date?
    let artwork: Data?

    init?(_ info: [String: Any]?) {
        let prefix: String = "kMRMediaRemoteNowPlayingInfo"
        guard let info, let title = info[prefix + "Title"] as? String, !title.isEmpty else { return nil }
        self.title = title
        artist = info[prefix + "Artist"] as? String
        album = info[prefix + "Album"] as? String
        duration = (info[prefix + "Duration"] as? NSNumber)?.doubleValue
        elapsed = (info[prefix + "ElapsedTime"] as? NSNumber)?.doubleValue
        rate = (info[prefix + "PlaybackRate"] as? NSNumber)?.doubleValue
        timestamp = info[prefix + "Timestamp"] as? Date
        artwork = info[prefix + "ArtworkData"] as? Data
    }
}
