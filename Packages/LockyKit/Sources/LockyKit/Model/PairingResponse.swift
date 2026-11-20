import Foundation

/// Answer of the iPhone to a ``PairingRequest``, sent in clear text.
public struct PairingResponse: Codable, Sendable, Equatable {
    public var deviceID: UUID
    public var deviceName: String
    public var deviceModel: String
    /// Hardware identifier, e.g. "iPhone18,1".
    public var modelIdentifier: String
    /// X9.63 representation of the iPhone ephemeral P-256 key agreement public key.
    public var publicKey: Data
    /// 32 random bytes.
    public var nonce: Data

    public init(deviceID: UUID, deviceName: String, deviceModel: String, modelIdentifier: String, publicKey: Data, nonce: Data) {
        self.deviceID = deviceID
        self.deviceName = deviceName
        self.deviceModel = deviceModel
        self.modelIdentifier = modelIdentifier
        self.publicKey = publicKey
        self.nonce = nonce
    }
}
