import Foundation

/// Every Mac Locky supports (Apple silicon, the only ones macOS 27 runs on), embedded in the
/// iPhone and Apple Watch apps as in the original Locky: the product image of each model and
/// color, its screen made transparent, so the app draws the wallpaper of the Mac behind it. Only
/// the wallpaper travels then.
///
/// The images come from macOS itself (its CoreTypes), cropped and sized by the catalog tool. A Mac
/// released after this version of Locky falls back to the symbol of its family.
public enum MacCatalog {
    public struct Entry: Sendable, Equatable {
        /// Name of the image in the asset catalog of the app.
        public let asset: String
        /// Where the screen is in the image, `nil` for the Macs without a display.
        public let screen: NormalizedRect?
    }

    /// Every type of Mac the catalog knows (model and color), for the Mac lab of the iPhone.
    public static var typeIdentifiers: [String] {
        types.keys.sorted()
    }

    /// The image of a Mac, from its exact type (model and color) or, failing that, its model
    /// identifier.
    public static func entry(deviceType: String?, model: String?) -> Entry? {
        if let deviceType, let entry = types[deviceType] {
            return entry
        }
        if let model, let type = models[model] {
            return types[type]
        }
        return nil
    }
}
