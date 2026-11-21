import CryptoKit
import Foundation
import Testing
@testable import LockyKit

struct WireCodecTests {
    @Test
    func handshakeTravelsInClearText() throws {
        let hello: LockyMessage = .sessionHello(.init(participantID: .init(), nonce: .randomBytes(count: 32)))
        let payload: Data = try WireCodec.encodeClearText(hello)
        var channel: SecureChannel?
        #expect(try WireCodec.decode(payload, channel: &channel) == hello)
    }

    @Test
    func commandsCannotBeSentInClearText() {
        #expect(throws: LockyProtocolError.encryptionRequired) {
            try WireCodec.encodeClearText(.unlock(password: "secret", origin: .app))
        }
    }

    @Test
    func forgedClearTextCommandIsRejected() throws {
        var forged: Data = .init([0x00])
        forged.append(try JSONEncoder().encode(LockyMessage.unlock(password: "x", origin: .app)))
        var channel: SecureChannel?
        #expect(throws: LockyProtocolError.encryptionRequired) {
            try WireCodec.decode(forged, channel: &channel)
        }
    }

    @Test
    func encryptedRoundTrip() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let macNonce: Data = .randomBytes(count: 32)
        let phoneNonce: Data = .randomBytes(count: 32)
        var phone: SecureChannel = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        var mac: SecureChannel? = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac)
        let message: LockyMessage = .unlock(password: "p@ss wörd", origin: .watch)
        let payload: Data = try WireCodec.encodeEncrypted(message, channel: &phone)
        #expect(try WireCodec.decode(payload, channel: &mac) == message)
    }

    @Test(arguments: SetupProgress.allCases)
    func setupProgressIsEncrypted(progress: SetupProgress) throws {
        #expect(throws: LockyProtocolError.encryptionRequired) {
            try WireCodec.encodeClearText(.setupProgress(progress))
        }
        let key: SymmetricKey = .init(size: .bits256)
        let macNonce: Data = .randomBytes(count: 32)
        let phoneNonce: Data = .randomBytes(count: 32)
        var mac: SecureChannel = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac)
        var phone: SecureChannel? = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        let payload: Data = try WireCodec.encodeEncrypted(.setupProgress(progress), channel: &mac)
        #expect(try WireCodec.decode(payload, channel: &phone) == .setupProgress(progress))
    }

    @Test
    func dashboardMessagesRoundTrip() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let macNonce: Data = .randomBytes(count: 32)
        let phoneNonce: Data = .randomBytes(count: 32)
        var mac: SecureChannel = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac)
        var phone: SecureChannel? = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        let date: Date = .init(timeIntervalSince1970: 1_800_000_000)
        let messages: [LockyMessage] = [
            .macMetrics(.init(
                cpuUsage: 0.31,
                coreCount: 12,
                memoryUsed: 27_000_000_000,
                memoryTotal: 34_359_738_368,
                memoryPressure: .warning,
                diskAvailable: 171_971_225_094,
                diskTotal: 994_631_127_040,
                diskName: "Macintosh HD",
                battery: .init(level: 82, isCharging: true, isOnPower: true, minutesRemaining: nil),
                thermalState: .nominal,
                bootDate: date,
                outputVolume: 0.75,
                isMuted: false,
                date: date
            )),
            .nowPlayingChanged(revision: "r1"),
            .nowPlaying(.init(
                title: "Clair de lune",
                artist: "Claude Debussy",
                album: "Suite bergamasque",
                appName: "Musique",
                isPlaying: true,
                duration: 301,
                elapsed: 96.5,
                elapsedDate: date,
                artworkID: "8283bd9a1d227d20",
                artwork: nil
            )),
            .nowPlaying(nil),
            .mediaCommand(.setVolume(0.4)),
            .mediaCommand(.seek(83.5)),
            .dashboard(isVisible: true)
        ]
        for message in messages {
            let payload: Data = try WireCodec.encodeEncrypted(message, channel: &mac)
            #expect(try WireCodec.decode(payload, channel: &phone) == message)
        }
    }

    @Test
    func artworkNeverTravelsOverBluetooth() throws {
        let track: NowPlaying = .init(
            title: "T", artist: nil, album: nil, appName: nil, isPlaying: true,
            duration: 100, elapsed: 10, elapsedDate: .now, artworkID: "a1", artwork: Data(repeating: 7, count: 4_000)
        )
        let decoded: NowPlaying = try JSONDecoder().decode(NowPlaying.self, from: JSONEncoder().encode(track))
        #expect(decoded.artwork == nil)
        #expect(decoded.artworkID == "a1")
    }

    @Test
    func nowPlayingProgressesOnlyWhilePlaying() {
        let start: Date = .init(timeIntervalSince1970: 0)
        var track: NowPlaying = .init(
            title: "T", artist: nil, album: nil, appName: nil, isPlaying: true,
            duration: 100, elapsed: 10, elapsedDate: start, artworkID: nil, artwork: nil
        )
        #expect(track.elapsed(at: start.addingTimeInterval(5)) == 15)
        #expect(track.elapsed(at: start.addingTimeInterval(500)) == 100)
        track.isPlaying = false
        #expect(track.elapsed(at: start.addingTimeInterval(5)) == 10)
    }

    @Test
    func encryptedPayloadNeedsASession() throws {
        let key: SymmetricKey = .init(size: .bits256)
        var phone: SecureChannel = .init(
            pairingKey: key,
            macNonce: .randomBytes(count: 32),
            phoneNonce: .randomBytes(count: 32),
            role: .phone
        )
        let payload: Data = try WireCodec.encodeEncrypted(.ping, channel: &phone)
        var none: SecureChannel?
        #expect(throws: LockyProtocolError.noSession) {
            try WireCodec.decode(payload, channel: &none)
        }
    }
}
