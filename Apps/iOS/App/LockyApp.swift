import SwiftUI

@main
struct LockyApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appDelegate.model)
                .readScreenFold()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                appDelegate.model.sceneBecameActive()
            }
        }
    }
}
