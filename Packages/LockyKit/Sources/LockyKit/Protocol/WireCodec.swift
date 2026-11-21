import Foundation

/// Turns ``LockyMessage`` values into frames payloads and back.
///
/// Payload layout: one kind byte followed by either the JSON encoded message (clear text) or a
/// ``SecureChannel`` sealed box (encrypted).
public enum WireCodec {
    private enum Kind: UInt8 {
        case clearText = 0x00
        case encrypted = 0x01
    }

    /// Encodes a handshake message in clear text.
    public static func encodeClearText(_ message: LockyMessage) throws -> Data {
        guard message.isHandshake else { throw LockyProtocolError.encryptionRequired }
        var payload: Data = .init([Kind.clearText.rawValue])
        payload.append(try JSONEncoder().encode(message))
        return payload
    }

    /// Encrypts a message with the session channel.
    public static func encodeEncrypted(_ message: LockyMessage, channel: inout SecureChannel) throws -> Data {
        let plaintext: Data = try JSONEncoder().encode(message)
        var payload: Data = .init([Kind.encrypted.rawValue])
        payload.append(try channel.seal(plaintext))
        return payload
    }

    /// Decodes a payload. Encrypted payloads require a channel; clear text payloads must be handshakes.
    public static func decode(_ payload: Data, channel: inout SecureChannel?) throws -> LockyMessage {
        guard let kindByte = payload.first, let kind = Kind(rawValue: kindByte) else {
            throw LockyProtocolError.malformedPayload
        }
        let body: Data = payload.dropFirst()
        switch kind {
        case .clearText:
            let message: LockyMessage = try JSONDecoder().decode(LockyMessage.self, from: body)
            guard message.isHandshake else { throw LockyProtocolError.encryptionRequired }
            return message
        case .encrypted:
            guard var current = channel else { throw LockyProtocolError.noSession }
            let plaintext: Data = try current.open(body)
            channel = current
            // Authentic: a message that does not decode comes from a newer peer.
            guard let message = try? JSONDecoder().decode(LockyMessage.self, from: plaintext) else {
                throw LockyProtocolError.unknownMessage
            }
            guard !message.isHandshake else { throw LockyProtocolError.malformedPayload }
            return message
        }
    }
}
