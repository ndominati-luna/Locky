import CryptoKit
import Foundation
import Testing
@testable import LockyKit

/// Messages of Locky 1.0.2, and what an older or newer peer makes of them.
struct CompatibilityTests {
    private static func channels() -> (mac: SecureChannel, phone: SecureChannel) {
        let key: SymmetricKey = .init(size: .bits256)
        let macNonce: Data = .randomBytes(count: 32)
        let phoneNonce: Data = .randomBytes(count: 32)
        return (
            .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac),
            .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        )
    }

    @Test
    func newMessagesRoundTrip() throws {
        var (mac, phone): (SecureChannel, SecureChannel) = Self.channels()
        var received: SecureChannel? = mac
        let settings: LockAnimationSettings = .init(
            style: .flight,
            title: "Bonne nuit",
            titleStyle: .typewriter,
            backgroundKind: .color,
            backgroundColor: "0B1E3F",
            hasBackgroundImage: false
        )
        for message: LockyMessage in [.lockAnimation(settings), .previewLockAnimation, .checkForUpdates, .autoLock(isEnabled: false)] {
            let payload: Data = try WireCodec.encodeEncrypted(message, channel: &phone)
            #expect(try WireCodec.decode(payload, channel: &received) == message)
        }
        _ = mac
    }

    /// The iPhone tells the Mac how often it shows the distance, only once the Mac announced it can
    /// hear it.
    @Test
    func proximityInterestRoundTrips() throws {
        var (mac, phone): (SecureChannel, SecureChannel) = Self.channels()
        var received: SecureChannel? = mac
        for interest: ProximityInterest in [.live, .glance, .none] {
            let message: LockyMessage = .proximityInterest(interest)
            let payload: Data = try WireCodec.encodeEncrypted(message, channel: &phone)
            #expect(try WireCodec.decode(payload, channel: &received) == message)
        }
        #expect(ProximityInterest.live.interval == .milliseconds(500))
        #expect(ProximityInterest.glance.interval == .seconds(5))
        #expect(ProximityInterest.none.interval == nil)
        #expect(LockyFeature.current.contains(LockyFeature.proximityOnDemand.rawValue))
        _ = mac
    }

    /// The Unlock button of the Mac, shown or hidden from either side, and what the Mac tells of
    /// it and of Touch ID; a status of an older Mac tells neither.
    @Test
    func unlockButtonRoundTrips() throws {
        var (mac, phone): (SecureChannel, SecureChannel) = Self.channels()
        var received: SecureChannel? = mac
        for isShown in [true, false] {
            let message: LockyMessage = .unlockButton(isShown: isShown)
            let payload: Data = try WireCodec.encodeEncrypted(message, channel: &phone)
            #expect(try WireCodec.decode(payload, channel: &received) == message)
        }
        #expect(LockyFeature.current.contains(LockyFeature.unlockButton.rawValue))
        let status: MacStatus = .init(
            macID: .init(),
            name: "Mac",
            model: "Mac16,1",
            productName: "MacBook Pro",
            family: .macBook,
            systemVersion: "27.2",
            userName: "Nico",
            lockState: .unlocked,
            lockStateDate: .now,
            isAutoLockEnabled: true,
            unlockCount: 0,
            features: LockyFeature.current,
            hasTouchID: true,
            showsUnlockButton: false
        )
        var json: [String: Any] = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(status)) as? [String: Any])
        #expect(try JSONDecoder().decode(MacStatus.self, from: JSONSerialization.data(withJSONObject: json)) == status)
        json["hasTouchID"] = nil
        json["showsUnlockButton"] = nil
        json["features"] = nil
        let older: MacStatus = try JSONDecoder().decode(MacStatus.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(older.hasTouchID == nil)
        #expect(older.showsUnlockButton == nil)
        #expect(!older.supports(.unlockButton))
        _ = mac
    }

    /// A message of a newer Locky is authentic but unknown: ignored, the session stays.
    @Test
    func unknownMessageKeepsTheSession() throws {
        var (mac, phone): (SecureChannel, SecureChannel) = Self.channels()
        let future: Data = .init(#"{"teleport":{"_0":"moon"}}"#.utf8)
        var payload: Data = .init([0x01])
        payload.append(try mac.seal(future))
        var received: SecureChannel? = phone
        #expect(throws: LockyProtocolError.unknownMessage) {
            try WireCodec.decode(payload, channel: &received)
        }
        // The channel moved on: the next message decodes.
        let next: Data = try WireCodec.encodeEncrypted(.ping, channel: &mac)
        #expect(try WireCodec.decode(next, channel: &received) == .ping)
        _ = phone
    }

    @Test
    func unknownStyleFallsBack() throws {
        let json: Data = .init(#"{"style":"warp","title":"Hi","titleStyle":"glitter","backgroundKind":"video","backgroundColor":"112233","hasBackgroundImage":true}"#.utf8)
        let settings: LockAnimationSettings = try JSONDecoder().decode(LockAnimationSettings.self, from: json)
        #expect(settings.style == .iris)
        #expect(settings.titleStyle == .reveal)
        #expect(settings.backgroundKind == .color)
        #expect(settings.title == "Hi")
        #expect(settings.backgroundColor == "112233")
        #expect(settings.hasBackgroundImage)
    }

    @Test
    func olderStatusesDecodeWithoutFeatures() throws {
        let status: DeviceStatus = .init(
            name: "iPhone",
            model: "iPhone",
            modelIdentifier: "iPhone18,1",
            systemVersion: "27.2",
            appVersion: "1.0.1 (4)",
            batteryLevel: 80,
            preferences: .init(),
            macImagesVersion: nil
        )
        var json: [String: Any] = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(status)) as? [String: Any])
        json["features"] = nil
        let older: DeviceStatus = try JSONDecoder().decode(DeviceStatus.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!older.supports(.lockAnimation))
        var current: DeviceStatus = status
        current.features = LockyFeature.current
        #expect(current.supports(.lockAnimation))
        #expect(current.supports(.macUpdates))
    }

    @Test
    func feedListsReleasesNewestFirst() throws {
        let feed: String = """
        <?xml version="1.0" standalone="yes"?>
        <rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
            <channel>
                <title>Locky</title>
                <item>
                    <title>1.0.0</title>
                    <pubDate>Fri, 20 Nov 2026 20:39:43 +0100</pubDate>
                    <sparkle:version>1</sparkle:version>
                    <sparkle:shortVersionString>1.0.0</sparkle:shortVersionString>
                    <enclosure url="https://locky.lunabee.studio/mac/Locky-1.0.0.dmg" length="1"/>
                </item>
                <item>
                    <title>1.0.1</title>
                    <pubDate>Sat, 21 Nov 2026 13:20:52 +0100</pubDate>
                    <sparkle:version>4</sparkle:version>
                    <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
                    <description sparkle:format="markdown"><![CDATA[# Locky 1.0.1

        - La musique du Mac s'affiche presque instantanément.
        - Les ailes se replacent.
        ]]></description>
                </item>
            </channel>
        </rss>
        """
        let releases: [MacRelease] = MacReleaseFeed.parse(Data(feed.utf8))
        #expect(releases.map(\.build) == [4, 1])
        #expect(releases[0].version == "1.0.1")
        #expect(releases[0].noteLines == ["La musique du Mac s'affiche presque instantanément.", "Les ailes se replacent."])
        #expect(releases[1].notes == nil)
        #expect(releases[0].date == Date(timeIntervalSince1970: 1_795_263_652))
    }
}
