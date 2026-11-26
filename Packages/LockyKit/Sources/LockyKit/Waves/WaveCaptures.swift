import Foundation

/// What the Mac measured during a ``WaveScan``.
public struct MacWaveCapture: Codable, Sendable, Hashable {
    /// The Wi-Fi networks the Mac heard, strongest first.
    public var wifiNetworks: [WiFiNetwork]
    /// The network the Mac uses, `nil` when it uses none (or its Wi-Fi is off).
    public var wifiConnection: WiFiConnection?
    /// macOS hid the names of the networks: Locky may not use Location Services.
    public var areNetworkNamesHidden: Bool
    /// Bluetooth Low Energy devices heard by the Mac, strongest first.
    public var bluetoothDevices: [BluetoothNeighbor]
    /// Classic Bluetooth devices: those found around, and those paired with the Mac.
    public var classicDevices: [ClassicBluetoothDevice]
    /// The link between the Mac and the iPhone lying next to it, `nil` when the iPhone was away.
    public var link: LinkQuality?

    public init(
        wifiNetworks: [WiFiNetwork] = [],
        wifiConnection: WiFiConnection? = nil,
        areNetworkNamesHidden: Bool = false,
        bluetoothDevices: [BluetoothNeighbor] = [],
        classicDevices: [ClassicBluetoothDevice] = [],
        link: LinkQuality? = nil
    ) {
        self.wifiNetworks = wifiNetworks
        self.wifiConnection = wifiConnection
        self.areNetworkNamesHidden = areNetworkNamesHidden
        self.bluetoothDevices = bluetoothDevices
        self.classicDevices = classicDevices
        self.link = link
    }
}

/// What the iPhone measured during a ``WaveScan``.
public struct PhoneWaveCapture: Codable, Sendable, Hashable {
    /// Bluetooth Low Energy devices heard by the iPhone, strongest first.
    public var bluetoothDevices: [BluetoothNeighbor]
    /// `nil` when Locky may not use the microphone.
    public var sound: SoundSpectrum?
    /// `nil` when the iPhone has no magnetometer (or Locky may not use it).
    public var magneticField: MagneticField?
    /// `nil` without a mobile network (no SIM, airplane mode, iPad…).
    public var cellular: CellularTechnology?

    public init(
        bluetoothDevices: [BluetoothNeighbor] = [],
        sound: SoundSpectrum? = nil,
        magneticField: MagneticField? = nil,
        cellular: CellularTechnology? = nil
    ) {
        self.bluetoothDevices = bluetoothDevices
        self.sound = sound
        self.magneticField = magneticField
        self.cellular = cellular
    }
}

// MARK: - Wi-Fi

/// The frequency bands of Wi-Fi.
public enum WiFiBand: String, Codable, Sendable, CaseIterable, Comparable {
    case ghz2_4
    case ghz5
    case ghz6

    /// Center frequency of a channel of this band, in MHz.
    public func frequency(ofChannel channel: Int) -> Double {
        switch self {
        case .ghz2_4: channel == 14 ? 2484 : 2407 + 5 * Double(channel)
        case .ghz5: 5000 + 5 * Double(channel)
        case .ghz6: channel == 2 ? 5935 : 5950 + 5 * Double(channel)
        }
    }

    /// The range of frequencies drawn for this band, in MHz.
    public var frequencyRange: ClosedRange<Double> {
        switch self {
        case .ghz2_4: 2400...2485
        case .ghz5: 5150...5895
        case .ghz6: 5925...7125
        }
    }

    /// `true` for the band Bluetooth shares with Wi-Fi.
    public var isSharedWithBluetooth: Bool {
        self == .ghz2_4
    }

    public static func < (lhs: WiFiBand, rhs: WiFiBand) -> Bool {
        allCases.firstIndex(of: lhs) ?? 0 < allCases.firstIndex(of: rhs) ?? 0
    }
}

/// How a Wi-Fi network is protected.
public enum WiFiSecurity: String, Codable, Sendable {
    case open
    case wep
    case wpa
    case wpa2
    case wpa3
    case enterprise
    case unknown
}

/// A Wi-Fi network (one access point) heard by the Mac.
public struct WiFiNetwork: Codable, Sendable, Hashable, Identifiable {
    /// The access point (BSSID), or a stand-in when macOS hides it.
    public var id: String
    /// `nil` for a hidden network, or when macOS hides the names (no Location Services).
    public var ssid: String?
    /// `nil` when macOS hides it (no Location Services).
    public var bssid: String?
    /// Signal, in dBm.
    public var rssi: Int
    /// Noise on its channel, in dBm.
    public var noise: Int?
    public var channel: Int
    public var band: WiFiBand
    /// Width of the channel, in MHz.
    public var channelWidth: Int
    public var security: WiFiSecurity
    /// The network the Mac uses.
    public var isCurrent: Bool

    public init(
        id: String,
        ssid: String?,
        bssid: String?,
        rssi: Int,
        noise: Int?,
        channel: Int,
        band: WiFiBand,
        channelWidth: Int,
        security: WiFiSecurity,
        isCurrent: Bool
    ) {
        self.id = id
        self.ssid = ssid
        self.bssid = bssid
        self.rssi = rssi
        self.noise = noise
        self.channel = channel
        self.band = band
        self.channelWidth = channelWidth
        self.security = security
        self.isCurrent = isCurrent
    }

    /// Center frequency, in MHz.
    public var frequency: Double {
        band.frequency(ofChannel: channel)
    }

    /// Lowest and highest frequencies it occupies, in MHz. A wider channel of 5 or 6 GHz bonds a
    /// fixed group of 20 MHz channels, the one its primary channel (the one reported) belongs to;
    /// at 2.4 GHz, it is drawn around its primary channel.
    public var frequencySpan: ClosedRange<Double> {
        let width: Double = Double(max(channelWidth, 20))
        let center: Double = band.frequency(ofChannel: centerChannel)
        return (center - width / 2)...(center + width / 2)
    }

    /// The channel at the center of the group it bonds (its primary channel at 20 MHz).
    public var centerChannel: Int {
        let span: Int = max(channelWidth, 20) / 5
        guard span > 4, band != .ghz2_4 else { return channel }
        let base: Int
        switch band {
        case .ghz6:
            base = 1
        case .ghz5:
            base = channel >= 149 ? 149 : channel >= 100 ? 100 : 36
        case .ghz2_4:
            base = channel
        }
        let start: Int = base + (channel - base) / span * span
        return start + (span - 4) / 2
    }
}

/// The Wi-Fi connection of the Mac.
public struct WiFiConnection: Codable, Sendable, Hashable {
    /// `nil` when macOS hides it (no Location Services).
    public var ssid: String?
    public var rssi: Int
    public var noise: Int
    public var channel: Int
    public var band: WiFiBand
    public var channelWidth: Int
    /// Rate of the link, in Mbit/s.
    public var transmitRate: Double
    /// Generation: "4" (802.11n), "5" (ac), "6" (ax), "7" (be); `nil` when older or unknown.
    public var generation: Int?

    public init(
        ssid: String?,
        rssi: Int,
        noise: Int,
        channel: Int,
        band: WiFiBand,
        channelWidth: Int,
        transmitRate: Double,
        generation: Int?
    ) {
        self.ssid = ssid
        self.rssi = rssi
        self.noise = noise
        self.channel = channel
        self.band = band
        self.channelWidth = channelWidth
        self.transmitRate = transmitRate
        self.generation = generation
    }

    /// Signal above the noise, in dB.
    public var signalToNoise: Int {
        rssi - noise
    }
}

// MARK: - Bluetooth

/// A Bluetooth Low Energy device heard around (its advertisements).
public struct BluetoothNeighbor: Codable, Sendable, Hashable, Identifiable {
    /// Identifier given by the device that heard it (the same device has another one on the other
    /// side, and many devices change their address every few minutes).
    public var id: String
    public var name: String?
    /// Median signal of its advertisements, in dBm.
    public var rssi: Int
    public var strongestRSSI: Int
    /// Advertisements heard during the measurement.
    public var sightings: Int
    /// Bluetooth company identifier of its manufacturer data.
    public var companyID: UInt16?
    /// Services it advertises.
    public var serviceUUIDs: [String]
    public var isConnectable: Bool?
    /// Transmit power it advertises, in dBm.
    public var txPower: Int?

    public init(
        id: String,
        name: String?,
        rssi: Int,
        strongestRSSI: Int,
        sightings: Int,
        companyID: UInt16?,
        serviceUUIDs: [String],
        isConnectable: Bool?,
        txPower: Int?
    ) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.strongestRSSI = strongestRSSI
        self.sightings = sightings
        self.companyID = companyID
        self.serviceUUIDs = serviceUUIDs
        self.isConnectable = isConnectable
        self.txPower = txPower
    }

    /// Strong enough to be close (a meter or two): it competes the most with the link of Locky.
    public var isNearby: Bool {
        rssi >= WaveImpact.nearbyBluetoothRSSI
    }

    /// The manufacturer, when its identifier is a well known one.
    public var company: BluetoothCompany? {
        companyID.flatMap(BluetoothCompany.init(rawValue:))
    }
}

/// Manufacturers whose Bluetooth company identifier is recognized.
public enum BluetoothCompany: UInt16, Sendable, CaseIterable {
    case microsoft = 0x0006
    case apple = 0x004C
    case samsung = 0x0075
    case garmin = 0x0087
    case bose = 0x009E
    case google = 0x00E0
    case sony = 0x012D
    case amazon = 0x0171
    case huawei = 0x027D
    case xiaomi = 0x038F

    public var name: String {
        switch self {
        case .microsoft: "Microsoft"
        case .apple: "Apple"
        case .samsung: "Samsung"
        case .garmin: "Garmin"
        case .bose: "Bose"
        case .google: "Google"
        case .sony: "Sony"
        case .amazon: "Amazon"
        case .huawei: "Huawei"
        case .xiaomi: "Xiaomi"
        }
    }
}

/// A classic Bluetooth device (speakers, headphones, cars, keyboards…), found around by the Mac or
/// paired with it.
public struct ClassicBluetoothDevice: Codable, Sendable, Hashable, Identifiable {
    /// Its address.
    public var id: String
    public var name: String?
    /// Signal in dBm; `nil` when unknown (paired but not around).
    public var rssi: Int?
    public var kind: BluetoothDeviceKind
    public var isPaired: Bool
    /// Connected to the Mac: it shares the Bluetooth radio of the Mac with Locky.
    public var isConnected: Bool

    public init(id: String, name: String?, rssi: Int?, kind: BluetoothDeviceKind, isPaired: Bool, isConnected: Bool) {
        self.id = id
        self.name = name
        self.rssi = rssi
        self.kind = kind
        self.isPaired = isPaired
        self.isConnected = isConnected
    }
}

/// The major class of a classic Bluetooth device.
public enum BluetoothDeviceKind: String, Codable, Sendable {
    case computer
    case phone
    case network
    case audio
    case peripheral
    case imaging
    case wearable
    case toy
    case health
    case other

    /// From the major class of its class of device (bits 8 to 12).
    public init(classOfDevice: UInt32) {
        self.init(majorClass: (classOfDevice >> 8) & 0x1F)
    }

    public init(majorClass: UInt32) {
        switch majorClass {
        case 1: self = .computer
        case 2: self = .phone
        case 3: self = .network
        case 4: self = .audio
        case 5: self = .peripheral
        case 6: self = .imaging
        case 7: self = .wearable
        case 8: self = .toy
        case 9: self = .health
        default: self = .other
        }
    }

    public var systemImage: String {
        switch self {
        case .computer: "laptopcomputer"
        case .phone: "iphone"
        case .network: "network"
        case .audio: "headphones"
        case .peripheral: "keyboard"
        case .imaging: "printer"
        case .wearable: "applewatch"
        case .toy: "gamecontroller"
        case .health: "heart"
        case .other: "dot.radiowaves.left.and.right"
        }
    }
}

// MARK: - Link

/// The link between the Mac and the iPhone during the measurement, the iPhone lying still next to
/// the Mac: how steady its signal is tells how precise the distance will be here.
public struct LinkQuality: Codable, Sendable, Hashable {
    /// Signal read by the Mac (about three times a second), in dBm.
    public var samples: [Double]
    /// Seconds since the start of the measurement of each sample.
    public var times: [Double]
    public var averageRSSI: Double
    /// Standard deviation of the signal, in dB.
    public var deviation: Double
    /// Times the signal was not read for more than ``dropoutThreshold`` seconds.
    public var dropouts: Int

    /// A gap longer than this between two readings counts as a dropout.
    public static let dropoutThreshold: Double = 1.5

    public init(samples: [Double], times: [Double]) {
        self.samples = samples
        self.times = times
        let count: Double = Double(max(samples.count, 1))
        let average: Double = samples.reduce(0, +) / count
        averageRSSI = average
        deviation = (samples.reduce(0) { $0 + ($1 - average) * ($1 - average) } / count).squareRoot()
        dropouts = zip(times, times.dropFirst()).count { $1 - $0 > Self.dropoutThreshold }
    }
}

// MARK: - Sound

/// The sound around the iPhone: level and spectrum by third of an octave.
public struct SoundSpectrum: Codable, Sendable, Hashable {
    /// Centers of the bands, in Hz (``bandCenters``).
    public var frequencies: [Double]
    /// Level of each band, in dB relative to full scale.
    public var levels: [Double]
    /// Average level, in dB relative to full scale.
    public var averageLevel: Double
    /// Loudest moment, in dB relative to full scale.
    public var peakLevel: Double
    /// The loudest frequency, in Hz.
    public var dominantFrequency: Double?

    public init(frequencies: [Double], levels: [Double], averageLevel: Double, peakLevel: Double, dominantFrequency: Double?) {
        self.frequencies = frequencies
        self.levels = levels
        self.averageLevel = averageLevel
        self.peakLevel = peakLevel
        self.dominantFrequency = dominantFrequency
    }

    /// Thirds of an octave from 25 Hz to 20 kHz.
    public static let bandCenters: [Double] = (-16...13).map { 1000 * pow(2, Double($0) / 3) }
}

// MARK: - Magnetic field

/// The magnetic field around the iPhone, in microteslas. The Earth alone gives 25 to 65 µT; magnets
/// (speakers, the lid and the MagSafe of a MacBook) add a lot right next to them.
public struct MagneticField: Codable, Sendable, Hashable {
    /// Strength of the field about ten times a second, in µT.
    public var samples: [Double]
    public var average: Double
    public var strongest: Double
    public var weakest: Double
    /// Calibrated by iOS (the iPhone's own field removed); raw readings otherwise.
    public var isCalibrated: Bool

    public init(samples: [Double], isCalibrated: Bool) {
        self.samples = samples
        self.isCalibrated = isCalibrated
        average = samples.isEmpty ? 0 : samples.reduce(0, +) / Double(samples.count)
        strongest = samples.max() ?? 0
        weakest = samples.min() ?? 0
    }

    /// What the Earth gives on its own, in µT.
    public static let earthRange: ClosedRange<Double> = 25...65
}

// MARK: - Mobile network

/// The generation of the mobile network the iPhone uses.
public enum CellularTechnology: String, Codable, Sendable {
    case fiveG
    case fourG
    case threeG
    case twoG

    /// From a radio access technology of Core Telephony (`CTRadioAccessTechnology…`).
    public init?(radioAccessTechnology: String) {
        let name: String = radioAccessTechnology.replacing("CTRadioAccessTechnology", with: "")
        switch name {
        case "NR", "NRNSA": self = .fiveG
        case "LTE": self = .fourG
        case "WCDMA", "HSDPA", "HSUPA", "CDMAEVDORev0", "CDMAEVDORevA", "CDMAEVDORevB", "eHRPD": self = .threeG
        case "GPRS", "Edge", "CDMA1x": self = .twoG
        default: return nil
        }
    }

    public var name: String {
        switch self {
        case .fiveG: "5G"
        case .fourG: "4G"
        case .threeG: "3G"
        case .twoG: "2G"
        }
    }
}
