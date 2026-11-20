import Foundation
import Testing
@testable import LockyKit

struct FrameAssemblerTests {
    @Test(arguments: [1, 7, 20, 182, 512])
    func roundTripAcrossChunkSizes(chunkLength: Int) throws {
        let payload: Data = .randomBytes(count: 5_000)
        var assembler: FrameAssembler = .init()
        var received: [Data] = []
        for chunk in FrameAssembler.chunks(for: payload, maximumChunkLength: chunkLength) {
            #expect(chunk.count <= chunkLength)
            received += try assembler.append(chunk)
        }
        #expect(received == [payload])
    }

    @Test
    func severalFramesInOneChunk() throws {
        let first: Data = .init("first".utf8)
        let second: Data = .init("second".utf8)
        let bytes: Data = FrameAssembler.chunks(for: first, maximumChunkLength: 1_000)[0]
            + FrameAssembler.chunks(for: second, maximumChunkLength: 1_000)[0]
        var assembler: FrameAssembler = .init()
        #expect(try assembler.append(bytes) == [first, second])
    }

    @Test
    func emptyPayload() throws {
        var assembler: FrameAssembler = .init()
        let chunks: [Data] = FrameAssembler.chunks(for: .init(), maximumChunkLength: 20)
        #expect(try assembler.append(chunks[0]) == [Data()])
    }

    @Test
    func rejectsOversizedFrames() {
        var assembler: FrameAssembler = .init()
        let header: Data = .init([0xFF, 0xFF, 0xFF, 0xFF])
        #expect(throws: LockyProtocolError.frameTooLarge) {
            try assembler.append(header)
        }
    }
}
