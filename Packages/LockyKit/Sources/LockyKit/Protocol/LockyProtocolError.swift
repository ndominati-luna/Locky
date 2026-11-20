import Foundation

/// Errors raised while encoding, decoding or authenticating messages.
public enum LockyProtocolError: Error, Sendable, Equatable {
    /// The payload could not be parsed.
    case malformedPayload
    /// A non handshake message was received or sent without encryption.
    case encryptionRequired
    /// An encrypted payload was received before a session was established.
    case noSession
    /// The frame announces a size above ``FrameAssembler/maximumFrameLength``.
    case frameTooLarge
    /// The authentication tag is invalid: wrong key or tampered data.
    case authenticationFailed
    /// The message counter did not increase: replayed or reordered message.
    case replayDetected
    /// The message was sealed by the wrong side of the link.
    case wrongDirection
    /// The peer public key is invalid.
    case invalidPublicKey
}
