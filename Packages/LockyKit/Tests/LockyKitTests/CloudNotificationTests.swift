import Foundation
import Testing
@testable import LockyKit

/// Every Locky of the iCloud account gets the pushes of all subscriptions: only the Mac acts on
/// the one of the settings left for it.
struct CloudNotificationTests {
    /// The payload CloudKit sends for a query subscription.
    private static func push(subscriptionID: String) -> [AnyHashable: Any] {
        [
            "aps": ["content-available": 1],
            "ck": [
                "ce": 2,
                "cid": "iCloud.studio.lunabee.locky",
                "nid": UUID().uuidString,
                "qry": [
                    "dbs": 1,
                    "fo": 2,
                    "rid": "settings-\(UUID().uuidString)",
                    "sid": subscriptionID,
                    "zid": "Locky",
                    "zoid": "_defaultOwner",
                ],
            ],
        ]
    }

    @Test
    func macSettingsPushIsRecognized() {
        #expect(CloudSync.isMacSettingsNotification(Self.push(subscriptionID: "locky-mac-settings")))
    }

    @Test
    func otherPushesAreNot() {
        #expect(!CloudSync.isMacSettingsNotification(Self.push(subscriptionID: "locky-mac-status")))
        #expect(!CloudSync.isMacSettingsNotification(Self.push(subscriptionID: "locky-intrusions")))
        #expect(!CloudSync.isMacSettingsNotification(["aps": ["content-available": 1]]))
    }
}
