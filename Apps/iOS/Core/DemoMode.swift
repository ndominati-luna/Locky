#if DEBUG
import Foundation
import LockyKit

/// Sample data for screenshots and UI reviews in the simulator (no Bluetooth there).
///
/// Launch with `-LockyDemo YES`. Optional images are read from the app Documents folder
/// (`demo-wallpaper.jpg`, `demo-user.jpg`, `demo-phone.png`); the Mac comes from the catalog of the
/// app (a MacBook Pro 14" 2021, space gray).
enum DemoMode {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemo")
    }

    /// Screen to open (`-LockyDemoTab settings|intrusions|intrusion`).
    static var initialPath: [AppRoute] {
        switch UserDefaults.standard.string(forKey: "LockyDemoTab") {
        case "settings": [.settings]
        case "intrusions": [.intrusions]
        case "intrusion": [.intrusions, .intrusion(id: "demo-1")]
        default: []
        }
    }

    /// Pairing step to display instead of the paired interface (`-LockyDemoPairing code|done|calibrating`).
    static var pairingStep: PairingStep? {
        switch UserDefaults.standard.string(forKey: "LockyDemoPairing") {
        case "code": .confirmCode(code: "482913", macName: "MacBook Pro")
        case "calibrating": .calibrating(.near)
        case "calibratingFar": .calibrating(.far)
        case "measuring": .measuring(.near)
        case "done": .completed
        default: nil
        }
    }

    /// Guided first try to display (`-LockyDemoSetup waiting|walkAway|comeBack|magic|tour`).
    enum SetupDemo {
        case phase(SetupPhase)
        /// The whole first try, played in a loop-free sequence.
        case tour
    }

    static var setup: SetupDemo? {
        switch UserDefaults.standard.string(forKey: "LockyDemoSetup") {
        case "waiting": .phase(.waitingForMac)
        case "walkAway": .phase(.walkAway)
        case "comeBack": .phase(.comeBack)
        case "magic": .phase(.magic)
        case "tour": .tour
        default: nil
        }
    }

    /// Lock state to display (`-LockyDemoLocked YES`).
    static var isLocked: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoLocked")
    }

    /// The video of the first Locky (`-LockyDemoStory YES`).
    static var showsStory: Bool {
        isEnabled && UserDefaults.standard.bool(forKey: "LockyDemoStory")
    }

    /// The page of the Mac open in its sheet (`-LockyDemoMacPanel YES`).
    static var showsMacPanel: Bool {
        isEnabled && UserDefaults.standard.bool(forKey: "LockyDemoMacPanel")
    }

    /// The Mac out of reach (`-LockyDemoOutOfReach YES`).
    static var isOutOfReach: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemoOutOfReach")
    }

    /// `-LockyDemoMacModel studio|mini|pro`: a Mac without a display, under the Pro Display XDR.
    /// `-LockyDemoMacType com.apple.imac-2024-blue -LockyDemoMacProduct "iMac (24-inch, 2024)"`: any
    /// Mac of the catalog, its family read from its name (screenshots of every Mac).
    private static var mac: (model: String, productName: String, family: MacFamily, deviceType: String) {
        if let deviceType = UserDefaults.standard.string(forKey: "LockyDemoMacType") {
            let productName: String = UserDefaults.standard.string(forKey: "LockyDemoMacProduct") ?? "Mac"
            return ("Mac", productName, MacFamily(productName: productName), deviceType)
        }
        return switch UserDefaults.standard.string(forKey: "LockyDemoMacModel") {
        case "studio": ("Mac16,9", "Mac Studio (2025)", .macStudio, "com.apple.macstudio-2025")
        case "mini": ("Mac16,10", "Mac mini (2024)", .macMini, "com.apple.macmini-2024")
        case "pro": ("Mac14,8", "Mac Pro (2023)", .macPro, "com.apple.macpro-2023")
        default: ("MacBookPro18,4", "MacBook Pro (14-inch, 2021)", .macBook, "com.apple.macbookpro-14-2021-space-gray")
        }
    }

    static func macStatus(macID: UUID) -> MacStatus {
        .init(
            macID: macID,
            // `-LockyDemoMacName "…"` checks long names in widgets and the Live Activity.
            name: UserDefaults.standard.string(forKey: "LockyDemoMacName") ?? mac.productName.components(separatedBy: " (").first ?? "Mac",
            model: mac.model,
            productName: mac.productName,
            family: mac.family,
            systemVersion: "27.2",
            userName: "Alex Martin",
            lockState: isLocked ? .locked : .unlocked,
            lockStateDate: .now.addingTimeInterval(-1_260),
            isAutoLockEnabled: true,
            unlockCount: 1_284,
            // `-LockyDemoCamera denied|notDetermined|unavailable` shows the camera warning.
            cameraAccess: UserDefaults.standard.string(forKey: "LockyDemoCamera").flatMap(CameraAccess.init(rawValue:)) ?? .authorized,
            deviceType: mac.deviceType,
            // `-LockyDemoMacBuild 1` shows an update for the Mac.
            appVersion: "1.0.2",
            appBuild: UserDefaults.standard.integer(forKey: "LockyDemoMacBuild") > 0 ? UserDefaults.standard.integer(forKey: "LockyDemoMacBuild") : 5,
            features: LockyFeature.current
        )
    }

    static let lockAnimation: LockAnimationSettings = .init(
        style: .flight,
        title: "Bonne nuit",
        titleStyle: .typewriter,
        backgroundKind: .color,
        backgroundColor: "0B1E3F",
        hasBackgroundImage: false
    )

    static var visuals: MacVisuals {
        .init(
            wallpaper: document("demo-wallpaper.jpg"),
            userPicture: document("demo-user.jpg"),
            phone: document("demo-phone.png")
        )
    }

    static func intrusions(macID: UUID) -> [IntrusionReport] {
        [
            .init(id: "demo-1", macID: macID, macName: "MacBook Pro", date: .now.addingTimeInterval(-3_600), photo: document("demo-intruder.jpg")),
            .init(id: "demo-2", macID: macID, macName: "MacBook Pro", date: .now.addingTimeInterval(-90_000), photo: nil)
        ]
    }

    /// State of a busy MacBook Pro.
    static func metrics(cpuUsage: Double) -> MacMetrics {
        .init(
            cpuUsage: cpuUsage,
            coreCount: 10,
            memoryUsed: 11_800_000_000,
            memoryTotal: 17_179_869_184,
            memoryPressure: .normal,
            diskAvailable: 171_971_225_094,
            diskTotal: 494_384_795_648,
            diskName: "Macintosh HD",
            battery: .init(level: 76, isCharging: false, isOnPower: false, minutesRemaining: 312),
            thermalState: .nominal,
            bootDate: .now.addingTimeInterval(-3 * 86_400 - 4 * 3_600),
            outputVolume: 0.62,
            isMuted: false,
            date: .now
        )
    }

    private static let tracks: [(title: String, artist: String, album: String, duration: TimeInterval)] = [
        ("Clair de lune", "Claude Debussy", "Suite bergamasque", 302),
        ("Gymnopédie No. 1", "Erik Satie", "Gymnopédies", 205),
        ("The Four Seasons: Spring", "Antonio Vivaldi", "Le quattro stagioni", 638)
    ]

    /// Demo tracks, in a loop. The artwork is read from `demo-artwork.heic` in Documents.
    static func track(_ index: Int, isPlaying: Bool) -> NowPlaying {
        let position: Int = ((index % tracks.count) + tracks.count) % tracks.count
        let track = tracks[position]
        let artwork: Data? = document("demo-artwork.heic")
        return .init(
            title: track.title,
            artist: track.artist,
            album: track.album,
            appName: "Music",
            isPlaying: isPlaying,
            duration: track.duration,
            elapsed: track.duration * 0.3,
            elapsedDate: .now,
            artworkID: artwork == nil ? nil : "demo-\(position)",
            artwork: artwork
        )
    }

    static func trackIndex(of playing: NowPlaying) -> Int? {
        tracks.firstIndex { $0.title == playing.title }
    }

    private static func document(_ name: String) -> Data? {
        try? Data(contentsOf: URL.documentsDirectory.appending(path: name))
    }
}
#endif
