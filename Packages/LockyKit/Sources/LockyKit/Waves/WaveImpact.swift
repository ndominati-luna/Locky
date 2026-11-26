import Foundation

/// What the waves measured in a ``WaveScan`` mean for Locky.
///
/// Locky estimates the distance from the strength of the Bluetooth signal of the iPhone, read by
/// the Mac. What blurs that signal:
/// - the link itself: measured with the iPhone lying still next to the Mac, its signal should
///   barely move; the more it moves, the less precise the distance;
/// - the Bluetooth devices around, which advertise on the same three channels and crowd the
///   frequencies the link hops between;
/// - Wi-Fi at 2.4 GHz, the band Bluetooth shares; above all when the Mac itself uses it: its Wi-Fi
///   and its Bluetooth then take turns on the same antenna;
/// - the devices connected to the Mac (headphones, keyboard…), which share its Bluetooth radio.
///
/// Sound and the magnetic field do nothing to Bluetooth: they are only shown.
public struct WaveImpact: Sendable, Hashable {
    /// How much the waves around weigh on Locky.
    public enum Level: Int, Sendable, Hashable, Comparable, CaseIterable {
        /// Nothing in the way: the distance stays precise.
        case calm
        /// Some traffic: the distance may hesitate a little.
        case busy
        /// Crowded: Locky may lock or unlock late.
        case crowded

        public init(score: Double) {
            self = score < 0.34 ? .calm : score < 0.67 ? .busy : .crowded
        }

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// What is judged.
    public enum Kind: String, Sendable, Hashable, CaseIterable {
        /// The link between the Mac and the iPhone.
        case link
        /// The Bluetooth devices around.
        case bluetooth
        /// Wi-Fi at 2.4 GHz.
        case wifi
        /// Classic Bluetooth devices connected to the Mac.
        case macBluetooth

        /// Share in the overall score.
        var weight: Double {
            switch self {
            case .link: 0.4
            case .bluetooth: 0.25
            case .wifi: 0.25
            case .macBluetooth: 0.1
            }
        }
    }

    /// One thing judged, from 0 (no effect) to 1 (in the way).
    public struct Factor: Sendable, Hashable, Identifiable {
        public var kind: Kind
        public var score: Double
        public var level: Level {
            .init(score: score)
        }

        public var id: Kind {
            kind
        }
    }

    /// What could be judged with what was measured, in the order of ``Kind``.
    public var factors: [Factor]
    /// From 0 (no effect) to 1 (in the way): weighted, and never far below the worst thing judged.
    public var score: Double
    public var level: Level {
        .init(score: score)
    }

    public init(factors: [Factor]) {
        self.factors = factors
        let totalWeight: Double = factors.reduce(0) { $0 + $1.kind.weight }
        let weighted: Double = totalWeight > 0 ? factors.reduce(0) { $0 + $1.score * $1.kind.weight } / totalWeight : 0
        // One thing badly in the way is not drowned by the others: the worst one raises the verdict
        // to a level below its own.
        let worst: Double = factors.map(\.score).max() ?? 0
        score = max(weighted, worst - Self.worstFactorMargin)
    }

    /// How far below the worst thing judged the verdict may stay.
    static let worstFactorMargin: Double = 0.3

    public init(scan: WaveScan) {
        var factors: [Factor] = []
        if let link = scan.mac?.link, link.samples.count >= 3 {
            factors.append(.init(kind: .link, score: Self.linkScore(link)))
        }
        let crowd: BluetoothCrowd = .init(scan: scan)
        if scan.mac != nil || scan.phone != nil {
            factors.append(.init(kind: .bluetooth, score: Self.bluetoothScore(crowd)))
        }
        if let mac = scan.mac {
            factors.append(.init(kind: .wifi, score: Self.wifiScore(mac)))
            factors.append(.init(kind: .macBluetooth, score: Self.macBluetoothScore(mac)))
        }
        self.init(factors: factors)
    }

    public func factor(_ kind: Kind) -> Factor? {
        factors.first { $0.kind == kind }
    }

    // MARK: - Thresholds

    /// A Bluetooth device at least this strong is close (a meter or two).
    public static let nearbyBluetoothRSSI: Int = -70
    /// A 2.4 GHz network at least this strong weighs on the link.
    public static let strongWiFiRSSI: Int = -75

    static func linkScore(_ link: LinkQuality) -> Double {
        // Still, side by side: within ±1.5 dB the distance is steady; at ±6 dB it jumps around.
        let steadiness: Double = (link.deviation - 1.5) / 4.5
        return clamp(steadiness + Double(link.dropouts) * 0.3)
    }

    static func bluetoothScore(_ crowd: BluetoothCrowd) -> Double {
        clamp(max(Double(crowd.total) / 80, Double(crowd.nearby) / 15))
    }

    static func wifiScore(_ mac: MacWaveCapture) -> Double {
        let strong: Int = mac.wifiNetworks.count { $0.band == .ghz2_4 && $0.rssi >= strongWiFiRSSI }
        let macOnSharedBand: Bool = mac.wifiConnection?.band == .ghz2_4
        return clamp(Double(strong) / 10 + (macOnSharedBand ? 0.5 : 0))
    }

    static func macBluetoothScore(_ mac: MacWaveCapture) -> Double {
        let connected: [ClassicBluetoothDevice] = mac.classicDevices.filter(\.isConnected)
        // Audio streams all the time; a keyboard or a mouse barely talks.
        let audio: Int = connected.count { $0.kind == .audio }
        return clamp(Double(audio) * 0.45 + Double(connected.count - audio) * 0.1)
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// The Bluetooth Low Energy devices around, as the most attentive of both devices heard them:
/// their identifiers differ on each side, so they cannot be added up.
public struct BluetoothCrowd: Sendable, Hashable {
    public var total: Int
    /// Close enough to compete the most (``WaveImpact/nearbyBluetoothRSSI``).
    public var nearby: Int

    public init(scan: WaveScan) {
        let mac: [BluetoothNeighbor] = scan.mac?.bluetoothDevices ?? []
        let phone: [BluetoothNeighbor] = scan.phone?.bluetoothDevices ?? []
        total = max(mac.count, phone.count)
        nearby = max(mac.count(where: \.isNearby), phone.count(where: \.isNearby))
    }
}
