import Foundation

/// Keys of the WatchConnectivity dictionaries. The images do not go through the iPhone: the Watch
/// fetches them from iCloud by itself.
public enum WatchMessageKey {
    /// Application context: JSON encoded ``LockySnapshot``.
    public static let snapshot: String = "snapshot"
    /// Message: raw value of a ``LockyCommand``.
    public static let command: String = "command"
    /// Reply: `Bool`, the command reached the Mac.
    public static let success: String = "success"
    /// Application context: the Mac has new images in iCloud, ``MacImages/version``.
    public static let imagesVersion: String = "imagesVersion"
}
