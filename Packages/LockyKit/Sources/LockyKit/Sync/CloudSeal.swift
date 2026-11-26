import CryptoKit
import Foundation

/// Seals what the iPhone and the Mac leave in iCloud for each other: encrypted and authenticated
/// with a key derived from the pairing key, bound to the Mac. iCloud only carries it: nobody
/// without the pairing key can read it or forge one, even with access to the iCloud account.
///
/// The sealed data is a version byte, then the combined ChaCha20-Poly1305 box (nonce, ciphertext,
/// tag). Each kind of content has its own label, so that one can never be opened as another.
enum CloudSeal {
    private static let version: UInt8 = 1

    static func seal(_ plaintext: Data, label: String, key pairingKey: SymmetricKey, macID: UUID) throws -> Data {
        let box: ChaChaPoly.SealedBox = try ChaChaPoly.seal(
            plaintext,
            using: sealingKey(pairingKey, label: label),
            authenticating: associatedData(label: label, macID: macID)
        )
        var data: Data = .init([version])
        data.append(box.combined)
        return data
    }

    /// Opens what ``seal(_:label:key:macID:)`` produced with the same label, key and Mac.
    static func open(_ data: Data, label: String, key pairingKey: SymmetricKey, macID: UUID) throws -> Data {
        guard data.first == version, data.count > 1 + 12 + 16 else { throw LockyProtocolError.malformedPayload }
        do {
            let box: ChaChaPoly.SealedBox = try .init(combined: data.dropFirst())
            return try ChaChaPoly.open(
                box,
                using: sealingKey(pairingKey, label: label),
                authenticating: associatedData(label: label, macID: macID)
            )
        } catch {
            throw LockyProtocolError.authenticationFailed
        }
    }

    private static func sealingKey(_ pairingKey: SymmetricKey, label: String) -> SymmetricKey {
        HKDF<SHA256>.deriveKey(inputKeyMaterial: pairingKey, info: Data(label.utf8), outputByteCount: 32)
    }

    private static func associatedData(label: String, macID: UUID) -> Data {
        var data: Data = .init(label.utf8)
        data.append(contentsOf: macID.uuidString.utf8)
        return data
    }
}
