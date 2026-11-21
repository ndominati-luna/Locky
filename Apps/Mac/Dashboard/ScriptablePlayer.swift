import AppKit

/// Players that can be asked what they play with AppleScript.
enum ScriptablePlayer: CaseIterable {
    case music
    case spotify

    var bundleIdentifier: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        }
    }

    private var name: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }

    /// Distributed notification the player sends on every change.
    var announcementName: String {
        switch self {
        case .music: "com.apple.Music.playerInfo"
        case .spotify: "com.spotify.client.PlaybackStateChanged"
        }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).isEmpty
    }

    /// The name of the app in the language of the Mac ("Musique" in French).
    var localizedName: String {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.localizedName ?? name
    }

    /// Whether the user refused to let Locky control the player. Not asked yet, AppleScript shows
    /// the prompt of macOS once.
    var isAutomationDenied: Bool {
        let target: NSAppleEventDescriptor = .init(bundleIdentifier: bundleIdentifier)
        guard let descriptor = target.aeDesc else { return true }
        let status: OSStatus = AEDeterminePermissionToAutomateTarget(descriptor, typeWildCard, typeWildCard, false)
        return status != noErr && status != OSStatus(errAEEventWouldRequireUserConsent)
    }

    /// Returns the position in the current track, in milliseconds.
    var positionScript: String {
        "tell application id \"\(bundleIdentifier)\" to return (player position * 1000) as integer"
    }

    /// Moves to `position` (seconds) in the current track. Written in milliseconds divided by
    /// 1 000: a decimal number would depend on the decimal separator of the region.
    func seekScript(to position: TimeInterval) -> String {
        "tell application id \"\(bundleIdentifier)\" to set player position to (\(Int((position * 1_000).rounded())) / 1000)"
    }

    /// Returns the position (ms), the artwork URL (Spotify) and the title of the current track,
    /// separated by the unit separator; Music writes the artwork to `file` instead. The title tells
    /// whether the player already moved to the announced track. Music has no artwork for a
    /// streamed track that is not in the library: only the fields then.
    func artworkScript(writingTo file: URL) -> String {
        switch self {
        case .music:
            """
            tell application id "\(bundleIdentifier)"
                set p to (player position * 1000) as integer
                set n to name of current track
                set d to missing value
                try
                    set d to raw data of artwork 1 of current track
                end try
            end tell
            if d is not missing value then
                set f to open for access (POSIX file "\(file.path(percentEncoded: false))") with write permission
                set eof f to 0
                write d to f
                close access f
            end if
            return (p as text) & (ASCII character 31) & "" & (ASCII character 31) & n
            """
        case .spotify:
            """
            tell application id "\(bundleIdentifier)"
                set p to (player position * 1000) as integer
                return (p as text) & (ASCII character 31) & (artwork url of current track) & (ASCII character 31) & (name of current track)
            end tell
            """
        }
    }

    /// Title, artist, album, duration (ms), position (ms), playing, artwork URL, separated by the
    /// unit separator. Numbers are integers: real numbers would follow the decimal separator of the
    /// user's region.
    var trackScript: String {
        let duration: String = switch self {
        case .music: "(duration of t * 1000) as integer"
        case .spotify: "(duration of t) as integer"
        }
        let artwork: String = switch self {
        case .music: "\"\""
        case .spotify: "artwork url of t"
        }
        return """
        if application id "\(bundleIdentifier)" is not running then return ""
        tell application id "\(bundleIdentifier)"
            if player state is stopped then return ""
            set t to current track
            set AppleScript's text item delimiters to (ASCII character 31)
            return {name of t, artist of t, album of t, \(duration), (player position * 1000) as integer, (player state is playing) as text, \(artwork)} as text
        end tell
        """
    }

    func track(from output: String) -> PlayerTrack? {
        let fields: [String] = output.components(separatedBy: "\u{1F}")
        guard fields.count >= 7, !fields[0].isEmpty else { return nil }
        let artwork: PlayerTrack.Artwork = switch self {
        case .music: .script(self)
        case .spotify: URL(string: fields[6]).map { .url($0) } ?? .script(self)
        }
        return .init(
            title: fields[0],
            artist: fields[1].isEmpty ? nil : fields[1],
            album: fields[2].isEmpty ? nil : fields[2],
            appName: localizedName,
            isPlaying: fields[5] == "true",
            duration: Double(fields[3]).map { $0 / 1000 },
            elapsed: Double(fields[4]).map { $0 / 1000 },
            elapsedDate: .now,
            artwork: artwork
        )
    }
}
