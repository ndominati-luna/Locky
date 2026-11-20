import Foundation

/// App Group storage shared by the iPhone app, its widgets, and (on watchOS) the watch app and its
/// complications.
public enum SharedStore {
    /// App Group identifier.
    public static let appGroupIdentifier: String = "group.studio.lunabee.locky"
    private static let snapshotKey: String = "locky.snapshot"
    private static let wallpaperFileName: String = "mac-wallpaper.jpg"
    private static let userPictureFileName: String = "mac-user-picture.jpg"
    private static let phoneImageFileName: String = "phone-device.png"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    /// Root of the App Group container, `nil` when the entitlement is missing.
    public static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    /// Last saved snapshot.
    public static func snapshot() -> LockySnapshot {
        guard
            let data = defaults?.data(forKey: snapshotKey),
            let snapshot = try? JSONDecoder().decode(LockySnapshot.self, from: data)
        else { return .unpaired }
        return snapshot
    }

    /// Saves a snapshot.
    public static func save(_ snapshot: LockySnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults?.set(data, forKey: snapshotKey)
    }

    /// Exact type of the Mac (``MacStatus/deviceType``), to pick its image in ``MacCatalog``.
    public static var deviceType: String? {
        get { defaults?.string(forKey: "locky.deviceType") }
        set { defaults?.set(newValue, forKey: "locky.deviceType") }
    }

    /// Model identifier of the Mac, when its exact type is unknown.
    public static var model: String? {
        get { defaults?.string(forKey: "locky.model") }
        set { defaults?.set(newValue, forKey: "locky.model") }
    }

    /// Where the screen is in the image of the Mac (``Rendition/widgetDevice`` and
    /// ``Rendition/activityDevice`` keep the proportions of the catalog image).
    public static var deviceScreen: NormalizedRect? {
        get { defaults?.string(forKey: "locky.deviceScreen").flatMap(NormalizedRect.init(stringValue:)) }
        set { defaults?.set(newValue?.stringValue, forKey: "locky.deviceScreen") }
    }

    /// Mac wallpaper (JPEG).
    public static var wallpaper: Data? {
        get { read(wallpaperFileName) }
        set { write(newValue, to: wallpaperFileName) }
    }

    /// Mac user picture.
    public static var userPicture: Data? {
        get { read(userPictureFileName) }
        set { write(newValue, to: userPictureFileName) }
    }

    /// Product image of this iPhone, rendered by the Mac.
    public static var phoneImage: Data? {
        get { read(phoneImageFileName) }
        set { write(newValue, to: phoneImageFileName) }
    }

    /// Ready to display images for the widgets and the Live Activity, written by the app: the Mac
    /// of the catalog (which only the app embeds) with its wallpaper drawn on screen, and small
    /// copies at the size they are shown (iOS refuses a Live Activity whose images exceed their
    /// place).
    public enum Rendition: String, CaseIterable, Sendable {
        case widgetDevice = "widget-mac-device.png"
        case activityDevice = "activity-mac-device.png"
        case widgetWallpaper = "widget-mac-wallpaper.png"
        case activityWallpaper = "activity-mac-wallpaper.png"
        case userPicture = "widget-mac-user-picture.png"
    }

    public static func rendition(_ rendition: Rendition) -> Data? {
        read(rendition.rawValue)
    }

    public static func setRendition(_ rendition: Rendition, _ data: Data?) {
        write(data, to: rendition.rawValue)
    }

    /// ``MacImages/version`` of the images above (Apple Watch, which fetches them from iCloud).
    public static var imagesVersion: String? {
        get { defaults?.string(forKey: "locky.imagesVersion") }
        set { defaults?.set(newValue, forKey: "locky.imagesVersion") }
    }

    /// Removes everything (used when unpairing).
    public static func reset() {
        defaults?.removeObject(forKey: snapshotKey)
        imagesVersion = nil
        deviceType = nil
        model = nil
        deviceScreen = nil
        wallpaper = nil
        userPicture = nil
        phoneImage = nil
        Rendition.allCases.forEach { setRendition($0, nil) }
    }

    private static func read(_ fileName: String) -> Data? {
        guard let url = containerURL?.appending(path: fileName) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func write(_ data: Data?, to fileName: String) {
        guard let url = containerURL?.appending(path: fileName) else { return }
        if let data {
            try? data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
