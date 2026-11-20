import Foundation

/// First pairing message, sent in clear text by the Mac.
///
/// The Mac only *commits* to its key here and reveals it with ``PairingKeyReveal`` once it received
/// the iPhone key. This prevents a man in the middle from grinding keys to forge a matching
/// verification code.
public struct PairingRequest: Codable, Sendable, Equatable {
    public var macID: UUID
    public var macName: String
    public var family: MacFamily
    /// SHA-256 of the Mac public key followed by the Mac nonce.
    public var commitment: Data

    public init(macID: UUID, macName: String, family: MacFamily, commitment: Data) {
        self.macID = macID
        self.macName = macName
        self.family = family
        self.commitment = commitment
    }
}
