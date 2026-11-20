#if DEBUG
import Foundation
import LockyKit

/// Sample state for screenshots in the simulator, which has neither the iPhone nor iCloud.
///
/// Launch with `-LockyDemo YES` (options: `-LockyDemoLocked YES`, `-LockyDemoOutOfReach YES`,
/// `-LockyDemoMacName "…"`). The Mac comes from the catalog of the Watch app, its wallpaper from
/// `demo-wallpaper.jpg` in the app Documents folder, as on the iPhone.
enum WatchDemo {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "LockyDemo")
    }

    static var snapshot: LockySnapshot {
        let defaults: UserDefaults = .standard
        return .init(
            isPaired: true,
            macName: defaults.string(forKey: "LockyDemoMacName") ?? "MacBook Pro",
            family: .macBook,
            isConnected: !defaults.bool(forKey: "LockyDemoOutOfReach"),
            lockState: defaults.bool(forKey: "LockyDemoLocked") ? .locked : .unlocked,
            lockStateDate: .now.addingTimeInterval(-1_260),
            isAutoLockEnabled: true,
            unlockOnlyFromWatch: false,
            lockDistance: 1.5,
            updatedAt: .now
        )
    }

    /// A MacBook Pro 14" (2021), space gray, from the catalog of the Watch app.
    static let deviceType: String = "com.apple.macbookpro-14-2021-space-gray"
    static let model: String = "MacBookPro18,4"

    static var wallpaper: Data? {
        document("demo-wallpaper.jpg")
    }

    private static func document(_ name: String) -> Data? {
        try? Data(contentsOf: URL.documentsDirectory.appending(path: name))
    }
}
#endif
