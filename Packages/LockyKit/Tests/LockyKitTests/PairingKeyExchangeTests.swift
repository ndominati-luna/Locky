import CryptoKit
import Foundation
import Testing
@testable import LockyKit

struct PairingKeyExchangeTests {
    private let macID: UUID = .init()
    private let deviceID: UUID = .init()

    @Test
    func bothSidesDeriveTheSameSecret() throws {
        let mac: PairingKeyExchange = .init()
        let phone: PairingKeyExchange = .init()
        let macSecret: PairingSecret = try mac.deriveSecret(
            macPublicKey: mac.publicKey,
            macNonce: mac.nonce,
            phonePublicKey: phone.publicKey,
            phoneNonce: phone.nonce,
            macID: macID,
            deviceID: deviceID
        )
        let phoneSecret: PairingSecret = try phone.deriveSecret(
            macPublicKey: mac.publicKey,
            macNonce: mac.nonce,
            phonePublicKey: phone.publicKey,
            phoneNonce: phone.nonce,
            macID: macID,
            deviceID: deviceID
        )
        #expect(macSecret.verificationCode == phoneSecret.verificationCode)
        #expect(macSecret.verificationCode.count == 6)
        let isNumeric: Bool = macSecret.verificationCode.allSatisfy { $0.isNumber }
        #expect(isNumeric)
        #expect(macSecret.key.withUnsafeBytes { Data($0) } == phoneSecret.key.withUnsafeBytes { Data($0) })
    }

    @Test
    func commitmentBindsKeyAndNonce() {
        let mac: PairingKeyExchange = .init()
        #expect(PairingKeyExchange.commitment(publicKey: mac.publicKey, nonce: mac.nonce) == mac.commitment)
        #expect(PairingKeyExchange.commitment(publicKey: mac.publicKey, nonce: .randomBytes(count: 32)) != mac.commitment)
    }

    @Test
    func manInTheMiddleGetsDifferentKeys() throws {
        let mac: PairingKeyExchange = .init()
        let phone: PairingKeyExchange = .init()
        let attacker: PairingKeyExchange = .init()
        // The attacker answers the Mac with its own key.
        let macSecret: PairingSecret = try mac.deriveSecret(
            macPublicKey: mac.publicKey,
            macNonce: mac.nonce,
            phonePublicKey: attacker.publicKey,
            phoneNonce: phone.nonce,
            macID: macID,
            deviceID: deviceID
        )
        let phoneSecret: PairingSecret = try phone.deriveSecret(
            macPublicKey: attacker.publicKey,
            macNonce: mac.nonce,
            phonePublicKey: phone.publicKey,
            phoneNonce: phone.nonce,
            macID: macID,
            deviceID: deviceID
        )
        #expect(macSecret.key.withUnsafeBytes { Data($0) } != phoneSecret.key.withUnsafeBytes { Data($0) })
    }

    @Test
    func rejectsInvalidPublicKey() {
        let mac: PairingKeyExchange = .init()
        #expect(throws: LockyProtocolError.invalidPublicKey) {
            try mac.deriveSecret(
                macPublicKey: mac.publicKey,
                macNonce: mac.nonce,
                phonePublicKey: .randomBytes(count: 65),
                phoneNonce: .randomBytes(count: 32),
                macID: macID,
                deviceID: deviceID
            )
        }
    }
}
