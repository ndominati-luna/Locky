import Foundation
import LockyKit

/// Images of the Live Activity: the small copies the app writes for it (``SharedStore/Rendition``).
///
/// iOS may refuse to display the content of a Live Activity whose images are larger than their
/// place (the simulator does not check it): the activity showed placeholders only. And the
/// extension does not embed the catalog of the Macs: the app draws the Mac with its wallpaper.
enum ActivityImages {
    /// The Mac with its wallpaper on screen, 92 points wide on the lock screen.
    static var device: Data? {
        SharedStore.rendition(.activityDevice)
    }

    /// The user picture, a few points wide on the imitation of the lock screen of the Mac.
    static var userPicture: Data? {
        SharedStore.rendition(.userPicture)
    }

    /// The wallpaper, blurred behind the lock screen presentation.
    static var wallpaper: Data? {
        SharedStore.rendition(.activityWallpaper)
    }
}
