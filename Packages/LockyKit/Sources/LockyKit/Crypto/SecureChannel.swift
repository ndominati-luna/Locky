import CryptoKit
import Foundation

/// Authenticated encryption of the messages exchanged on one Bluetooth link.
///
/// The session key is derived from the long term pairing key and from two fresh nonces (one per
/// device), so messages recorded during a previous session can never be replayed. Within a
/// session, every message carries a strictly increasing counter in its ChaCha20-Poly1305 nonce.
public struct SecureChannel: Sendable {
    /// Side of the link the channel belongs to.
    public enum Role: Sendable {
        case mac
        case phone

        fileprivate var tag: UInt8 {
            switch self {
            case .mac: 0x4D
            case .phone: 0x50
            }
        }

        fileprivate var peer: Role {
            switch self {
            case .mac: .phone
            case .phone: .mac
            }
        }
    }

    private let key: SymmetricKey
    private let role: Role
    private var sendCounter: UInt64 = 0
    private var lastReceivedCounter: UInt64 = 0

    public init(pairingKey: SymmetricKey, macNonce: Data, phoneNonce: Data, role: Role) {
        var salt: Data = macNonce
        salt.append(phoneNonce)
        key = HKDF<SHA256>.deriveKey(
            inputKeyMaterial: pairingKey,
            salt: salt,
            info: Data("Locky session v2".utf8),
            outputByteCount: 32
        )
        self.role = role
    }

    /// Encrypts and authenticates a plaintext.
    public mutating func seal(_ plaintext: Data) throws -> Data {
        sendCounter += 1
        let nonce: ChaChaPoly.Nonce = try .init(data: Self.nonceBytes(tag: role.tag, counter: sendCounter))
        let box: ChaChaPoly.SealedBox = try ChaChaPoly.seal(
            plaintext,
            using: key,
            nonce: nonce,
            authenticating: Data([role.tag])
        )
        return box.combined
    }

    /// Authenticates and decrypts a sealed box produced by the other side.
    public mutating func open(_ combined: Data) throws -> Data {
        guard combined.count >= 12 + 16 else { throw LockyProtocolError.malformedPayload }
        let nonceBytes: Data = combined.prefix(12)
        guard nonceBytes.first == role.peer.tag else { throw LockyProtocolError.wrongDirection }
        let counter: UInt64 = nonceBytes.suffix(8).reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
        guard counter > lastReceivedCounter else { throw LockyProtocolError.replayDetected }
        let plaintext: Data
        do {
            let box: ChaChaPoly.SealedBox = try .init(combined: combined)
            plaintext = try ChaChaPoly.open(box, using: key, authenticating: Data([role.peer.tag]))
        } catch {
            throw LockyProtocolError.authenticationFailed
        }
        lastReceivedCounter = counter
        return plaintext
    }

    private static func nonceBytes(tag: UInt8, counter: UInt64) -> Data {
        var bytes: Data = .init([tag, 0, 0, 0])
        bytes.append(contentsOf: withUnsafeBytes(of: counter.bigEndian) { Array($0) })
        return bytes
    }
}
