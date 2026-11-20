import CryptoKit
import Foundation

/// Result of a successful pairing key exchange.
public struct PairingSecret: Sendable {
    /// Long term symmetric key shared by the Mac and the iPhone.
    public let key: SymmetricKey
    /// Six digit code both devices display; the user checks they match.
    public let verificationCode: String
    /// Mac nonce of the pairing exchange.
    public let macNonce: Data
    /// iPhone nonce of the pairing exchange.
    public let phoneNonce: Data

    /// Channel used for the remaining pairing messages (confirmation, password, calibration).
    public func makeChannel(role: SecureChannel.Role) -> SecureChannel {
        .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: role)
    }
}
