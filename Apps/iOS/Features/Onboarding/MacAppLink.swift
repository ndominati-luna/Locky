import SwiftUI

/// Where to download the Mac app, and how the iPhone hands that link to the Mac.
///
/// The 2015 app emailed the link (Parse and Mandrill, both gone). Now the share sheet sends it
/// (AirDrop, Mail, Messages…), and Handoff offers it on its own to the Macs of the same Apple
/// Account: their Dock shows the browser with an iPhone badge, and a click downloads the disk image.
/// No Mac app declares the activity type, so the Mac opens `webpageURL` in its browser.
enum MacAppLink {
    static let download: URL = URL(string: "https://locky.lunabee.studio/locky-mac-install.dmg")!

    /// The Handoff activity of the link, declared in `NSUserActivityTypes` of `Info.plist`.
    static let handoffActivityType: String = "studio.lunabee.locky.mac-download"
}

extension View {
    /// Offers the download of the Mac app to the nearby Macs through Handoff while `isActive`.
    func handsOffMacAppLink(isActive: Bool = true) -> some View {
        userActivity(MacAppLink.handoffActivityType, isActive: isActive) { activity in
            activity.title = String(localized: "Locky for Mac")
            activity.webpageURL = MacAppLink.download
            activity.isEligibleForHandoff = true
            activity.isEligibleForSearch = false
            activity.isEligibleForPublicIndexing = false
        }
    }
}
