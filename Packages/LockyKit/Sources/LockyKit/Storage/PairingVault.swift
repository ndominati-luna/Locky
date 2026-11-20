import CryptoKit
import Foundation

/// Persists the pairing: record in user defaults, key in the keychain.
public struct PairingVault: Sendable {
    private static let recordKey: String = "locky.pairing.record"
    private static let keyAccount: String = "pairing.key"
    private static let localIdentifierKey: String = "locky.local.identifier"

    private let keychain: KeychainStore

    public init(keychain: KeychainStore = .init()) {
        self.keychain = keychain
    }

    /// Stable identifier of this device for Locky (not linked to any system identifier).
    public var localIdentifier: UUID {
        let defaults: UserDefaults = .standard
        if let string = defaults.string(forKey: Self.localIdentifierKey), let identifier = UUID(uuidString: string) {
            return identifier
        }
        let identifier: UUID = .init()
        defaults.set(identifier.uuidString, forKey: Self.localIdentifierKey)
        return identifier
    }

    /// The current pairing, if both the record and the key are present.
    public func load() -> (record: PairingRecord, key: SymmetricKey)? {
        guard
            let data = UserDefaults.standard.data(forKey: Self.recordKey),
            let record = try? JSONDecoder().decode(PairingRecord.self, from: data),
            let keyData = try? keychain.data(for: Self.keyAccount)
        else { return nil }
        return (record, SymmetricKey(data: keyData))
    }

    /// Persists a new pairing.
    public func save(record: PairingRecord, key: SymmetricKey) throws {
        let keyData: Data = key.withUnsafeBytes { Data($0) }
        try keychain.set(keyData, for: Self.keyAccount)
        UserDefaults.standard.set(try JSONEncoder().encode(record), forKey: Self.recordKey)
    }

    /// Updates the non secret part of the pairing.
    public func update(record: PairingRecord) throws {
        UserDefaults.standard.set(try JSONEncoder().encode(record), forKey: Self.recordKey)
    }

    /// Forgets the pairing.
    public func clear() {
        try? keychain.remove(Self.keyAccount)
        UserDefaults.standard.removeObject(forKey: Self.recordKey)
    }
}
