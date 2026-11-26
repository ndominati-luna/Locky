import CryptoKit
import Foundation

/// A setting with the moment it was chosen: between two choices, the most recent one wins, wherever
/// it was made.
public struct Dated<Value: Codable & Sendable & Equatable>: Codable, Sendable, Equatable {
    public var value: Value
    public var date: Date

    public init(_ value: Value, date: Date = .now) {
        self.value = value
        self.date = date
    }
}

/// The settings the Mac applies, as last chosen on the iPhone, each with the date it was chosen.
///
/// Changed while the Mac is in reach, a setting goes over Bluetooth at once. Out of reach, the
/// iPhone drops the whole envelope in iCloud, sealed with the pairing key, and the Mac picks it up;
/// back in reach, the iPhone sends it over Bluetooth too (``LockyMessage/macSettings(_:)``), in case
/// the Mac could not read iCloud meanwhile. The Mac keeps, setting by setting, the most recent
/// choice between these and its own (``newer(than:)``), so an old envelope never undoes a later
/// change made on the Mac.
public struct MacSettingsEnvelope: Codable, Sendable, Equatable {
    public var preferences: Dated<PhonePreferences>?
    /// "Locky activated" on the Mac.
    public var autoLock: Dated<Bool>?
    public var lockAnimation: Dated<LockAnimationSettings>?
    /// The Unlock button of the lock screen of the Mac (``LockyFeature/unlockButton``).
    public var unlockButton: Dated<Bool>?

    public init(
        preferences: Dated<PhonePreferences>? = nil,
        autoLock: Dated<Bool>? = nil,
        lockAnimation: Dated<LockAnimationSettings>? = nil,
        unlockButton: Dated<Bool>? = nil
    ) {
        self.preferences = preferences
        self.autoLock = autoLock
        self.lockAnimation = lockAnimation
        self.unlockButton = unlockButton
    }

    /// `true` when it holds no setting.
    public var isEmpty: Bool {
        preferences == nil && autoLock == nil && lockAnimation == nil && unlockButton == nil
    }

    /// The settings chosen after those the Mac holds: the ones to apply.
    public func newer(than clock: MacSettingsClock) -> MacSettingsEnvelope {
        func isNewer<Value>(_ setting: Dated<Value>?, than date: Date?) -> Dated<Value>? {
            guard let setting, setting.date > date ?? .distantPast else { return nil }
            return setting
        }
        return .init(
            preferences: isNewer(preferences, than: clock.preferences),
            autoLock: isNewer(autoLock, than: clock.autoLock),
            lockAnimation: isNewer(lockAnimation, than: clock.lockAnimation),
            unlockButton: isNewer(unlockButton, than: clock.unlockButton)
        )
    }
}

/// When the settings the Mac holds were chosen, on the Mac or on the iPhone: a setting of a
/// ``MacSettingsEnvelope`` only replaces an older one.
public struct MacSettingsClock: Codable, Sendable, Equatable {
    public var preferences: Date?
    public var autoLock: Date?
    public var lockAnimation: Date?
    public var unlockButton: Date?

    public init(preferences: Date? = nil, autoLock: Date? = nil, lockAnimation: Date? = nil, unlockButton: Date? = nil) {
        self.preferences = preferences
        self.autoLock = autoLock
        self.lockAnimation = lockAnimation
        self.unlockButton = unlockButton
    }

    /// Takes the dates of the settings just applied.
    public mutating func advance(to envelope: MacSettingsEnvelope) {
        if let date = envelope.preferences?.date {
            preferences = date
        }
        if let date = envelope.autoLock?.date {
            autoLock = date
        }
        if let date = envelope.lockAnimation?.date {
            lockAnimation = date
        }
        if let date = envelope.unlockButton?.date {
            unlockButton = date
        }
    }
}

// MARK: - Sealing

extension MacSettingsEnvelope {
    private static let label: String = "Locky Mac settings v1"

    /// Encrypted and authenticated with a key derived from the pairing key, bound to the Mac
    /// (``CloudSeal``): iCloud only carries it. An older envelope replayed there is older than what
    /// the Mac holds.
    public func sealed(key pairingKey: SymmetricKey, macID: UUID) throws -> Data {
        try CloudSeal.seal(JSONEncoder().encode(self), label: Self.label, key: pairingKey, macID: macID)
    }

    /// Opens what ``sealed(key:macID:)`` produced for this Mac with this pairing key.
    public init(sealed data: Data, key pairingKey: SymmetricKey, macID: UUID) throws {
        let plaintext: Data = try CloudSeal.open(data, label: Self.label, key: pairingKey, macID: macID)
        self = try JSONDecoder().decode(Self.self, from: plaintext)
    }
}
