import CryptoKit
import Foundation
import Testing
@testable import LockyKit

/// The settings of the Mac chosen on the iPhone out of reach: sealed for iCloud, merged by date.
struct MacSettingsEnvelopeTests {
    private static let macID: UUID = .init()
    private static let animation: LockAnimationSettings = .init(
        style: .curtain,
        title: "Bonne nuit",
        titleStyle: .gather,
        backgroundKind: .color,
        backgroundColor: "2B1240",
        hasBackgroundImage: false
    )

    private static func envelope(at date: Date) -> MacSettingsEnvelope {
        .init(
            preferences: .init(.init(intrusionDetection: true, lockDistance: 3), date: date),
            autoLock: .init(false, date: date),
            lockAnimation: .init(animation, date: date),
            unlockButton: .init(false, date: date)
        )
    }

    @Test
    func sealedRoundTrip() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let envelope: MacSettingsEnvelope = Self.envelope(at: .init(timeIntervalSinceReferenceDate: 800_000_000))
        let sealed: Data = try envelope.sealed(key: key, macID: Self.macID)
        #expect(try MacSettingsEnvelope(sealed: sealed, key: key, macID: Self.macID) == envelope)
        // Nothing readable in what iCloud stores.
        #expect(sealed.range(of: Data("Bonne nuit".utf8)) == nil)
    }

    /// Another pairing key (someone with access to iCloud, an older pairing) cannot read nor forge it.
    @Test
    func otherKeyIsRefused() throws {
        let sealed: Data = try Self.envelope(at: .now).sealed(key: .init(size: .bits256), macID: Self.macID)
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try MacSettingsEnvelope(sealed: sealed, key: .init(size: .bits256), macID: Self.macID)
        }
    }

    /// Sealed for one Mac, it is refused by another Mac paired with the same key.
    @Test
    func otherMacIsRefused() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let sealed: Data = try Self.envelope(at: .now).sealed(key: key, macID: Self.macID)
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try MacSettingsEnvelope(sealed: sealed, key: key, macID: .init())
        }
    }

    @Test
    func tamperedDataIsRefused() throws {
        let key: SymmetricKey = .init(size: .bits256)
        var sealed: Data = try Self.envelope(at: .now).sealed(key: key, macID: Self.macID)
        sealed[sealed.count / 2] ^= 0x01
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try MacSettingsEnvelope(sealed: sealed, key: key, macID: Self.macID)
        }
        #expect(throws: LockyProtocolError.malformedPayload) {
            try MacSettingsEnvelope(sealed: Data([0x02, 0x00]), key: key, macID: Self.macID)
        }
    }

    /// Only the settings chosen after those the Mac holds apply, setting by setting.
    @Test
    func onlyNewerSettingsApply() {
        let base: Date = .init(timeIntervalSinceReferenceDate: 800_000_000)
        let envelope: MacSettingsEnvelope = Self.envelope(at: base)
        // Nothing known on the Mac yet: everything applies.
        #expect(envelope.newer(than: .init()) == envelope)
        // Auto lock changed on the Mac afterwards; the preferences came over Bluetooth before.
        let clock: MacSettingsClock = .init(preferences: base - 60, autoLock: base + 60, lockAnimation: base)
        let newer: MacSettingsEnvelope = envelope.newer(than: clock)
        #expect(newer.preferences == envelope.preferences)
        #expect(newer.autoLock == nil)
        // The same date is the same choice, already applied.
        #expect(newer.lockAnimation == nil)
        // Never chosen on the Mac since it knows the setting: the choice of the iPhone applies.
        #expect(newer.unlockButton == envelope.unlockButton)
    }

    /// An envelope of an iPhone that does not know the Unlock button setting leaves it alone.
    @Test
    func olderEnvelopeHasNoUnlockButton() throws {
        let json: Data = .init(#"{"autoLock":{"value":false,"date":800000000}}"#.utf8)
        let envelope: MacSettingsEnvelope = try JSONDecoder().decode(MacSettingsEnvelope.self, from: json)
        #expect(envelope.unlockButton == nil)
        #expect(envelope.newer(than: .init()).unlockButton == nil)
        let clock: MacSettingsClock = try JSONDecoder().decode(
            MacSettingsClock.self,
            from: Data(#"{"preferences":800000000,"autoLock":800000000,"lockAnimation":800000000}"#.utf8)
        )
        #expect(clock.unlockButton == nil)
    }

    @Test
    func clockAdvancesToAppliedSettings() {
        let base: Date = .init(timeIntervalSinceReferenceDate: 800_000_000)
        var clock: MacSettingsClock = .init(preferences: base - 60, autoLock: base + 60, lockAnimation: nil)
        clock.advance(to: .init(preferences: .init(.init(), date: base)))
        #expect(clock == .init(preferences: base, autoLock: base + 60, lockAnimation: nil))
        #expect(MacSettingsEnvelope().isEmpty)
    }

    @Test
    func messageRoundTrip() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let macNonce: Data = .randomBytes(count: 32)
        let phoneNonce: Data = .randomBytes(count: 32)
        var phone: SecureChannel = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        var mac: SecureChannel? = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac)
        let message: LockyMessage = .macSettings(Self.envelope(at: .init(timeIntervalSinceReferenceDate: 800_000_000)))
        let payload: Data = try WireCodec.encodeEncrypted(message, channel: &phone)
        #expect(try WireCodec.decode(payload, channel: &mac) == message)
    }

    /// An envelope of a newer Locky, with settings this one does not know, still decodes.
    @Test
    func unknownSettingsAreIgnored() throws {
        let json: Data = .init(#"{"autoLock":{"value":true,"date":800000000},"wallpaper":{"value":"x","date":800000000}}"#.utf8)
        let envelope: MacSettingsEnvelope = try JSONDecoder().decode(MacSettingsEnvelope.self, from: json)
        #expect(envelope.autoLock == .init(true, date: .init(timeIntervalSinceReferenceDate: 800_000_000)))
        #expect(envelope.preferences == nil)
    }
}
