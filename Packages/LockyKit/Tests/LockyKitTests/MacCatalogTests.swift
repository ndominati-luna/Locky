import Foundation
import Testing
@testable import LockyKit

struct MacCatalogTests {
    @Test func exactTypeWins() throws {
        let entry: MacCatalog.Entry = try #require(MacCatalog.entry(deviceType: "com.apple.macbookpro-14-2021-silver", model: "MacBookPro18,3"))
        #expect(entry == MacCatalog.types["com.apple.macbookpro-14-2021-silver"])
        #expect(entry.screen != nil)
    }

    @Test func modelIdentifierFallsBackToTheDefaultColor() {
        #expect(MacCatalog.entry(deviceType: "com.apple.unknown-mac", model: "MacBookPro18,3") == MacCatalog.types["com.apple.macbookpro-14-2021"])
    }

    @Test func unknownMacHasNoImage() {
        #expect(MacCatalog.entry(deviceType: nil, model: "MacBookPro99,1") == nil)
        #expect(MacCatalog.entry(deviceType: nil, model: nil) == nil)
    }

    @Test func macsWithoutDisplayHaveNoScreen() throws {
        let mini: MacCatalog.Entry = try #require(MacCatalog.entry(deviceType: nil, model: "Macmini9,1"))
        #expect(mini.screen == nil)
    }

    @Test func everyScreenIsInsideItsImage() {
        for (type, entry) in MacCatalog.types {
            guard let screen = entry.screen else { continue }
            #expect(screen.x >= 0 && screen.y >= 0 && screen.x + screen.width <= 1.001 && screen.y + screen.height <= 1.001, "\(type)")
        }
    }

    @Test func statusCarriesTheDeviceType() throws {
        let status: MacStatus = .init(
            macID: .init(),
            name: "Mac",
            model: "MacBookPro18,4",
            productName: "MacBook Pro",
            family: .macBook,
            systemVersion: "27.2",
            userName: "Alex",
            lockState: .unlocked,
            lockStateDate: .now,
            isAutoLockEnabled: true,
            unlockCount: 0,
            deviceType: "com.apple.macbookpro-14-2021-space-gray"
        )
        let decoded: MacStatus = try JSONDecoder().decode(MacStatus.self, from: JSONEncoder().encode(status))
        #expect(decoded.deviceType == "com.apple.macbookpro-14-2021-space-gray")
    }
}
