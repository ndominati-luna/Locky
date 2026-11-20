import Foundation
import LockyKit

/// Stores the macOS session password in the iPhone keychain.
///
/// The item is readable once the iPhone has been unlocked after boot, so automatic unlocking keeps
/// working while the iPhone sits locked in a pocket. It never leaves the device unencrypted: it is
/// only sent inside the end-to-end encrypted Bluetooth session.
struct PasswordVault {
    private static let account: String = "mac.password"
    private let keychain: KeychainStore = .init()

    var hasPassword: Bool {
        (try? keychain.data(for: Self.account)) != nil
    }

    func password() -> String? {
        try? keychain.string(for: Self.account)
    }

    @discardableResult
    func save(_ password: String) -> Bool {
        (try? keychain.set(password, for: Self.account)) != nil
    }

    func clear() {
        try? keychain.remove(Self.account)
    }
}
