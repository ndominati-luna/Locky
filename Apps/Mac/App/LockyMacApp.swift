import SwiftUI

@main
struct LockyMacApp: App {
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate

    var body: some Scene {
        // Locky lives in the menu bar (native status menu, see StatusMenuController) and opens its
        // windows on demand (WindowManager): no regular scene.
        Settings {
            EmptyView()
        }
    }
}
