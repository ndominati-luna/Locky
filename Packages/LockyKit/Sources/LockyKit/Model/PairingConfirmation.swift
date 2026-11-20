import Foundation

/// Sent (encrypted) by the iPhone once the user confirmed the verification code.
public struct PairingConfirmation: Codable, Sendable, Equatable {
    /// Identifier of the pairing, also used as the advertised service UUID.
    public var pairingID: UUID

    public init(pairingID: UUID) {
        self.pairingID = pairingID
    }
}
