import Foundation

/// Clear text message opening a secure session between two already paired devices.
///
/// Only the Mac initiates sessions, so hellos can never ping-pong:
/// - Mac → iPhone, `echo == nil`: opens a session with a fresh Mac nonce;
/// - iPhone → Mac, `echo == Mac nonce`: answers it with a fresh iPhone nonce;
/// - iPhone → Mac, `echo == nil`: asks the Mac to open a new session (e.g. after iOS relaunched
///   Locky in background and lost the session keys).
public struct SessionHello: Codable, Sendable, Equatable {
    /// Identifier of the sender (Mac identifier or iPhone identifier).
    public var participantID: UUID
    /// 32 fresh random bytes, mixed into the session key.
    public var nonce: Data
    /// Nonce of the hello being answered, `nil` for an initiation (or a request on the iPhone side).
    public var echo: Data?

    public init(participantID: UUID, nonce: Data, echo: Data? = nil) {
        self.participantID = participantID
        self.nonce = nonce
        self.echo = echo
    }
}
