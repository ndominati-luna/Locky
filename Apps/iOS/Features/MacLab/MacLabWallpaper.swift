import Foundation
import ImageIO
import UIKit

/// A picture chosen in the Mac lab as the wallpaper of its Macs, in place of the one of the paired
/// Mac, in the lab alone: the screen of the Mac shows it, the background of the lab its blurred
/// copy. Kept in the lab's own folder for the next time, never in the stores of the app.
struct MacLabWallpaper {
    /// For the screen of the Mac, at most the size of a Retina iPhone screen.
    let image: UIImage
    /// A small copy, for the blurred background (``ImmersiveBackground``).
    let background: Data

    private static var file: URL {
        URL.applicationSupportDirectory.appending(path: "MacLab", directoryHint: .isDirectory).appending(path: "Wallpaper.jpg")
    }

    /// The picture of `data`, made smaller, or `nil` if it is not a picture.
    init?(data: Data) {
        guard
            let image = Self.thumbnail(data, maxPixelSize: 2048).flatMap(UIImage.init(data:)),
            let background = Self.thumbnail(data, maxPixelSize: 256)
        else { return nil }
        self.image = image
        self.background = background
    }

    /// The picture chosen last time, if any.
    static func stored() -> MacLabWallpaper? {
        (try? Data(contentsOf: file)).flatMap(MacLabWallpaper.init(data:))
    }

    /// Keeps it for the next time.
    func store() {
        guard let data = image.jpegData(compressionQuality: 0.88) else { return }
        try? FileManager.default.createDirectory(at: Self.file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: Self.file, options: .atomic)
    }

    /// Back to the wallpaper of the paired Mac.
    static func remove() {
        try? FileManager.default.removeItem(at: file)
    }

    private static func thumbnail(_ data: Data, maxPixelSize: Int) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: image).jpegData(compressionQuality: 0.9)
    }
}
