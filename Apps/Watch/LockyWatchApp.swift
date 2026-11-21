import LockyKit
import SwiftUI
import WatchKit

@main
struct LockyWatchApp: App {
    @WKApplicationDelegateAdaptor private var delegate: WatchAppDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var model: WatchModel = .shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environment(model)
                .task { model.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await model.refreshFromCloud() }
        }
        .backgroundTask(.appRefresh(WatchModel.refreshTaskIdentifier)) {
            await WatchModel.shared.refreshFromCloud()
            await MainActor.run { WatchModel.scheduleBackgroundRefresh() }
        }
    }
}

/// Registers for the silent pushes of iCloud (the Mac changed) and plans the background refreshes:
/// the Watch keeps its Mac up to date without the iPhone.
final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    func applicationDidFinishLaunching() {
        WatchModel.shared.start()
        WKApplication.shared().registerForRemoteNotifications()
        WatchModel.scheduleBackgroundRefresh()
    }

    func didReceiveRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> WKBackgroundFetchResult {
        // Settings left for the Mac: only the Mac cares.
        guard !CloudSync.isMacSettingsNotification(userInfo) else { return .noData }
        await WatchModel.shared.refreshFromCloud()
        return .newData
    }
}
