import CryptoKit
import Foundation

/// Ephemeral P-256 key agreement used once, while pairing a Mac and an iPhone.
///
/// Flow:
/// 1. Mac → iPhone: ``commitment`` (hash of the Mac key and nonce).
/// 2. iPhone → Mac: iPhone ``publicKey`` and ``nonce``.
/// 3. Mac → iPhone: Mac ``publicKey`` and ``nonce``; the iPhone checks the commitment.
/// 4. Both sides derive the same ``PairingSecret`` and display its verification code.
public struct PairingKeyExchange: Sendable {
    private let privateKey: P256.KeyAgreement.PrivateKey
    /// 32 random bytes generated for this exchange.
    public let nonce: Data

    public init() {
        privateKey = .init()
        nonce = .randomBytes(count: 32)
    }

    /// X9.63 representation of the public key.
    public var publicKey: Data {
        privateKey.publicKey.x963Representation
    }

    /// Commitment the Mac sends before revealing its key.
    public var commitment: Data {
        Self.commitment(publicKey: publicKey, nonce: nonce)
    }

    /// Computes the commitment of a public key and nonce.
    public static func commitment(publicKey: Data, nonce: Data) -> Data {
        var material: Data = .init("Locky commitment v2".utf8)
        material.append(publicKey)
        material.append(nonce)
        return Data(SHA256.hash(data: material))
    }

    /// Derives the shared pairing secret.
    ///
    /// - Parameters:
    ///   - macPublicKey: Mac public key (equal to ``publicKey`` on the Mac).
    ///   - macNonce: Mac nonce.
    ///   - phonePublicKey: iPhone public key (equal to ``publicKey`` on the iPhone).
    ///   - phoneNonce: iPhone nonce.
    ///   - macID: Mac identifier.
    ///   - deviceID: iPhone identifier.
    public func deriveSecret(
        macPublicKey: Data,
        macNonce: Data,
        phonePublicKey: Data,
        phoneNonce: Data,
        macID: UUID,
        deviceID: UUID
    ) throws -> PairingSecret {
        let peerKeyData: Data = publicKey == macPublicKey ? phonePublicKey : macPublicKey
        let peerKey: P256.KeyAgreement.PublicKey
        do {
            peerKey = try .init(x963Representation: peerKeyData)
        } catch {
            throw LockyProtocolError.invalidPublicKey
        }
        let sharedSecret: SharedSecret = try privateKey.sharedSecretFromKeyAgreement(with: peerKey)

        var transcript: Data = .init("Locky pairing v2".utf8)
        transcript.append(macPublicKey)
        transcript.append(macNonce)
        transcript.append(phonePublicKey)
        transcript.append(phoneNonce)
        transcript.append(macID.rawBytes)
        transcript.append(deviceID.rawBytes)
        let salt: Data = .init(SHA256.hash(data: transcript))

        let key: SymmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("Locky pairing key".utf8),
            outputByteCount: 32
        )
        let codeKey: SymmetricKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: Data("Locky verification code".utf8),
            outputByteCount: 4
        )
        let codeValue: UInt32 = codeKey.withUnsafeBytes { bytes in
            bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        }
        return .init(
            key: key,
            verificationCode: Self.formatCode(codeValue % 1_000_000),
            macNonce: macNonce,
            phoneNonce: phoneNonce
        )
    }

    private static func formatCode(_ value: UInt32) -> String {
        let digits: String = .init(value)
        return String(repeating: "0", count: max(0, 6 - digits.count)) + digits
    }
}
