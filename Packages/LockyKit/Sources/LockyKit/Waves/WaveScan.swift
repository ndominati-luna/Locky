import CryptoKit
import Foundation

/// A measurement of the waves around the Mac, made together by the Mac and the iPhone lying next to
/// it, under the name the user gave it (home, work…).
///
/// Each device measures what only it can hear: the Mac the Wi-Fi networks, Bluetooth (both kinds)
/// and the steadiness of its link with the iPhone; the iPhone Bluetooth too, the sound, the
/// magnetic field and the mobile network. Each leaves its own part in iCloud, sealed with the
/// pairing key (``WaveScanPart``); both devices read the whole measurement from there.
public struct WaveScan: Sendable, Hashable, Identifiable {
    public var id: UUID
    public var name: String
    public var date: Date
    /// What the Mac measured, `nil` when its part is missing (not in iCloud yet, or it failed).
    public var mac: MacWaveCapture?
    /// What the iPhone measured, `nil` when its part is missing (Locky was not on its screen).
    public var phone: PhoneWaveCapture?

    public init(id: UUID, name: String, date: Date, mac: MacWaveCapture? = nil, phone: PhoneWaveCapture? = nil) {
        self.id = id
        self.name = name
        self.date = date
        self.mac = mac
        self.phone = phone
    }

    /// How long both devices listen.
    public static let captureDuration: Duration = .seconds(20)

    /// Longest name kept.
    public static let maximumNameLength: Int = 40

    /// What the waves around mean for Locky.
    public var impact: WaveImpact {
        .init(scan: self)
    }

    /// Merges the parts of measurements, as read from iCloud: one measurement per identifier,
    /// newest first.
    public static func merging(_ parts: [WaveScanPart]) -> [WaveScan] {
        var scans: [UUID: WaveScan] = [:]
        for part in parts {
            var scan: WaveScan = scans[part.scanID] ?? .init(id: part.scanID, name: part.name, date: part.date)
            scan.apply(part)
            scans[part.scanID] = scan
        }
        return scans.values.sorted { $0.date > $1.date }
    }

    /// Adds the part of one device.
    public mutating func apply(_ part: WaveScanPart) {
        switch part.capture {
        case let .mac(capture):
            mac = capture
        case let .phone(capture):
            phone = capture
        }
    }
}

/// The device that measured a part of a ``WaveScan``.
public enum WaveScanSide: String, Codable, Sendable, CaseIterable {
    case mac
    case phone
}

/// What one device measured during a ``WaveScan``, as left in iCloud.
public struct WaveScanPart: Codable, Sendable, Hashable {
    public enum Capture: Codable, Sendable, Hashable {
        case mac(MacWaveCapture)
        case phone(PhoneWaveCapture)
    }

    public var scanID: UUID
    public var name: String
    public var date: Date
    public var capture: Capture

    public init(scanID: UUID, name: String, date: Date, capture: Capture) {
        self.scanID = scanID
        self.name = name
        self.date = date
        self.capture = capture
    }

    public var side: WaveScanSide {
        switch capture {
        case .mac: .mac
        case .phone: .phone
        }
    }
}

// MARK: - Sealing

extension WaveScanPart {
    private static let label: String = "Locky waves v1"

    /// Sealed with the pairing key for this Mac (``CloudSeal``): the networks and devices around
    /// the user, and the name of the place, are nobody else's business.
    public func sealed(key pairingKey: SymmetricKey, macID: UUID) throws -> Data {
        try CloudSeal.seal(JSONEncoder().encode(self), label: Self.label, key: pairingKey, macID: macID)
    }

    /// Opens what ``sealed(key:macID:)`` produced for this Mac with this pairing key.
    public init(sealed data: Data, key pairingKey: SymmetricKey, macID: UUID) throws {
        let plaintext: Data = try CloudSeal.open(data, label: Self.label, key: pairingKey, macID: macID)
        self = try JSONDecoder().decode(Self.self, from: plaintext)
    }
}

// MARK: - Coordination

/// Coordinates a ``WaveScan`` between the Mac and the iPhone, over Bluetooth
/// (``LockyMessage/waveScan(_:)``, between peers announcing ``LockyFeature/waveScan``).
public enum WaveScanSignal: Codable, Sendable, Equatable {
    /// Start measuring now, for ``WaveScan/captureDuration``, under this name.
    case start(id: UUID, name: String, date: Date)
    /// The part of the sender is in iCloud: read it.
    case saved(id: UUID)
    /// The sender cannot take part (Locky is not on the screen of the iPhone): the other device
    /// measures alone.
    case declined(id: UUID)
    /// The user stopped the measurement: both devices stop, nothing is kept.
    case cancelled(id: UUID)
}
