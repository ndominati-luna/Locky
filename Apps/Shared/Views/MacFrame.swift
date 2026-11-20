import LockyKit
import UIKit

/// The image of a Mac for ``MacDeviceImage``.
struct MacFrame {
    let image: UIImage
    /// Where the screen is in ``image``, `nil` for the Macs without a display.
    let screen: NormalizedRect?
    /// The wallpaper is already drawn on screen (renditions made by the app for its widgets and
    /// its Live Activity, which do not embed the catalog).
    var hasWallpaper: Bool = false

    /// The Mac from the catalog embedded in the app (``MacCatalog``), its screen transparent.
    /// `nil` for a Mac newer than this version of Locky, or in an extension (no catalog there).
    static func catalog(deviceType: String?, model: String?) -> MacFrame? {
        guard
            let entry = MacCatalog.entry(deviceType: deviceType, model: model),
            let image = UIImage(named: entry.asset)
        else { return nil }
        return .init(image: image, screen: entry.screen)
    }
}
