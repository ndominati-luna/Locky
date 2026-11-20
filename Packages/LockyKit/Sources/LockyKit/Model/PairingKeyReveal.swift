import Foundation

/// Third pairing message, sent in clear text by the Mac: opens the commitment of ``PairingRequest``.
public struct PairingKeyReveal: Codable, Sendable, Equatable {
    /// X9.63 representation of the Mac ephemeral P-256 key agreement public key.
    public var publicKey: Data
    /// 32 random bytes.
    public var nonce: Data

    public init(publicKey: Data, nonce: Data) {
        self.publicKey = publicKey
        self.nonce = nonce
    }
}
