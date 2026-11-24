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
            switch phase {
            case .active:
                appDelegate.model.sceneBecameActive()
            case .background:
                appDelegate.model.sceneEnteredBackground()
            default:
                break
            }
        }
    }
}
