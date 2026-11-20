import UIKit

/// Owns the model so it exists even when iOS launches Locky in background (Bluetooth restoration,
/// iCloud push, widget intent).
final class AppDelegate: NSObject, UIApplicationDelegate {
    let model: AppModel = .init()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Only a relaunch by Bluetooth counts: with scenes, every launch starts in background.
        model.start(inBackground: launchOptions?[.bluetoothPeripherals] != nil)
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any]
    ) async -> UIBackgroundFetchResult {
        await model.refreshFromCloud()
        return .newData
    }

    /// Closed from the app switcher while still running in background (iOS does not call it when
    /// Locky was suspended): closing Locky stops everything, Live Activity and Bluetooth included.
    func applicationWillTerminate(_ application: UIApplication) {
        model.prepareForTermination()
    }
}
