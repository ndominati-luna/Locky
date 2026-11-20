import Foundation

/// Images describing the Mac, rendered on the Mac for the iPhone, its widgets and the Apple Watch.
///
/// They go through iCloud (``CloudMacRecord``): the Mac uploads them, then tells the iPhone over
/// Bluetooth that a new version is there. The image of the Mac itself is not part of them: the
/// iPhone and the Watch embed every Mac (``MacCatalog``) and draw the wallpaper in its screen, as
/// the original Locky did. JPEG, PNG where transparency matters, sized for what the iPhone shows.
public struct MacImages: Codable, Sendable, Equatable {
    /// Hash of the content, lets the iPhone tell the Mac which version it already has.
    public var version: String
    /// Desktop wallpaper (JPEG), drawn in the screen of the Mac and blurred behind it.
    public var wallpaper: Data?
    /// macOS user picture (JPEG).
    public var userPicture: Data?
    /// The exact product image of the paired iPhone (model and color, PNG). iOS cannot draw its
    /// own product image, macOS can: the Mac renders it for the iPhone.
    public var phone: Data?

    public init(version: String, wallpaper: Data?, userPicture: Data?, phone: Data? = nil) {
        self.version = version
        self.wallpaper = wallpaper
        self.userPicture = userPicture
        self.phone = phone
    }

    /// Largest dimension of the wallpaper: the screen of the Mac at its largest on the iPhone (an
    /// unfolded iPhone Duo shows the Mac 560 points wide, its screen about 1,230 pixels).
    public static let wallpaperPixelSize: Int = 1_280
    /// Largest dimension of the user picture (a small round picture on the lock screen imitation).
    public static let userPicturePixelSize: Int = 256
    /// Largest dimension of the iPhone product image (the marker of the distance gauge).
    public static let phonePixelSize: Int = 200
}
