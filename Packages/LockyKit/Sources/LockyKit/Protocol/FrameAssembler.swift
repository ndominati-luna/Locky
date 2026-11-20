import Foundation

/// Splits payloads into Bluetooth sized chunks and reassembles them.
///
/// Each frame starts with its payload length as a big endian `UInt32`, followed by the payload.
/// GATT notifications and writes are delivered in order on a given link, so chunks can simply be
/// concatenated on the receiving side.
public struct FrameAssembler: Sendable {
    /// Largest accepted payload (protects against memory exhaustion).
    public static let maximumFrameLength: Int = 1_024 * 1_024

    private var buffer: Data = .init()

    public init() {}

    /// Builds the chunks to send for one payload.
    public static func chunks(for payload: Data, maximumChunkLength: Int) -> [Data] {
        precondition(maximumChunkLength > 0, "Chunk length must be positive")
        var frame: Data = .init()
        let length: UInt32 = .init(payload.count)
        frame.append(contentsOf: withUnsafeBytes(of: length.bigEndian) { Array($0) })
        frame.append(payload)
        var chunks: [Data] = []
        var start: Int = frame.startIndex
        while start < frame.endIndex {
            let end: Int = min(start + maximumChunkLength, frame.endIndex)
            chunks.append(frame.subdata(in: start..<end))
            start = end
        }
        return chunks
    }

    /// Appends a received chunk and returns every payload completed by it.
    public mutating func append(_ chunk: Data) throws -> [Data] {
        buffer.append(chunk)
        var payloads: [Data] = []
        while buffer.count >= 4 {
            let header: Data = buffer.prefix(4)
            let length: Int = header.reduce(0) { ($0 << 8) | Int($1) }
            guard length <= Self.maximumFrameLength else {
                reset()
                throw LockyProtocolError.frameTooLarge
            }
            guard buffer.count >= 4 + length else { break }
            let payloadStart: Int = buffer.startIndex + 4
            payloads.append(buffer.subdata(in: payloadStart..<(payloadStart + length)))
            buffer = Data(buffer.dropFirst(4 + length))
        }
        return payloads
    }

    /// Drops any partially received frame.
    public mutating func reset() {
        buffer = .init()
    }
}
