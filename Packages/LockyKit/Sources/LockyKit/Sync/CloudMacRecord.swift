import Foundation

/// The Mac information stored in iCloud (replaces the old Parse `Device` class).
///
/// The image of the Mac itself is not there: the iPhone and the Apple Watch embed every Mac
/// (``MacCatalog``) and draw the wallpaper in its screen.
public struct CloudMacRecord: Sendable, Equatable {
    public var status: MacStatus
    /// ``MacImages/version`` of the images below, `nil` when the record has no images yet.
    public var imagesVersion: String?
    /// Wallpaper (JPEG).
    public var wallpaper: Data?
    /// macOS user picture (JPEG).
    public var userPicture: Data?
    /// Product image of the paired iPhone, rendered by the Mac (PNG, transparent background).
    public var phoneImage: Data?
    public var modifiedAt: Date?
    /// `false` when an image was in iCloud but could not be read: iCloud downloads them to files
    /// protected while the iPhone is locked. The record must then be fetched again later.
    public var isComplete: Bool

    public init(
        status: MacStatus,
        imagesVersion: String?,
        wallpaper: Data?,
        userPicture: Data?,
        phoneImage: Data?,
        modifiedAt: Date? = nil,
        isComplete: Bool = true
    ) {
        self.status = status
        self.imagesVersion = imagesVersion
        self.wallpaper = wallpaper
        self.userPicture = userPicture
        self.phoneImage = phoneImage
        self.modifiedAt = modifiedAt
        self.isComplete = isComplete
    }
}
