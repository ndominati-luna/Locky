import CryptoKit
import Foundation
import Testing
@testable import LockyKit

struct SecureChannelTests {
    private let pairingKey: SymmetricKey = .init(size: .bits256)
    private let macNonce: Data = .randomBytes(count: 32)
    private let phoneNonce: Data = .randomBytes(count: 32)

    private func makeChannels() -> (mac: SecureChannel, phone: SecureChannel) {
        (
            .init(pairingKey: pairingKey, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac),
            .init(pairingKey: pairingKey, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        )
    }

    @Test
    func roundTripsBothWays() throws {
        var (mac, phone) = makeChannels()
        let toPhone: Data = try mac.seal(Data("hello phone".utf8))
        #expect(try phone.open(toPhone) == Data("hello phone".utf8))
        let toMac: Data = try phone.seal(Data("hello mac".utf8))
        #expect(try mac.open(toMac) == Data("hello mac".utf8))
    }

    @Test
    func rejectsReplays() throws {
        var (mac, phone) = makeChannels()
        let sealed: Data = try mac.seal(Data("unlock".utf8))
        _ = try phone.open(sealed)
        #expect(throws: LockyProtocolError.replayDetected) {
            try phone.open(sealed)
        }
    }

    @Test
    func rejectsReflectedMessages() throws {
        var (mac, _) = makeChannels()
        var otherMac: SecureChannel = makeChannels().mac
        let sealed: Data = try mac.seal(Data("ping".utf8))
        #expect(throws: LockyProtocolError.wrongDirection) {
            try otherMac.open(sealed)
        }
    }

    @Test
    func rejectsTampering() throws {
        var (mac, phone) = makeChannels()
        var sealed: Data = try mac.seal(Data("unlock".utf8))
        sealed[sealed.count - 1] ^= 0x01
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try phone.open(sealed)
        }
    }

    @Test
    func sessionsAreIndependent() throws {
        var mac: SecureChannel = .init(pairingKey: pairingKey, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac)
        var nextSessionPhone: SecureChannel = .init(
            pairingKey: pairingKey,
            macNonce: .randomBytes(count: 32),
            phoneNonce: .randomBytes(count: 32),
            role: .phone
        )
        let recorded: Data = try mac.seal(Data("unlock".utf8))
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try nextSessionPhone.open(recorded)
        }
    }
}
