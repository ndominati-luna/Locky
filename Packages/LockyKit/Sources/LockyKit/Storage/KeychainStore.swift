import Foundation
import Security

/// Minimal generic password keychain wrapper.
///
/// Items are only readable on this device, once it has been unlocked after boot: Locky must be
/// able to read them while the iPhone sits locked in a pocket.
public struct KeychainStore: Sendable {
    /// Keychain service of the items.
    public let service: String

    public init(service: String = "studio.lunabee.locky") {
        self.service = service
    }

    /// Reads the data stored for an account.
    public func data(for account: String) throws -> Data? {
        var query: [String: Any] = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError(status: status)
        }
    }

    /// Stores (or replaces) the data of an account.
    public func set(_ data: Data, for account: String) throws {
        try remove(account)
        var query: [String: Any] = baseQuery(account: account)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status: OSStatus = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    /// Removes the item of an account, if any.
    public func remove(_ account: String) throws {
        let status: OSStatus = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    /// Reads a UTF-8 string.
    public func string(for account: String) throws -> String? {
        try data(for: account).flatMap { String(data: $0, encoding: .utf8) }
    }

    /// Stores a UTF-8 string.
    public func set(_ string: String, for account: String) throws {
        try set(Data(string.utf8), for: account)
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
