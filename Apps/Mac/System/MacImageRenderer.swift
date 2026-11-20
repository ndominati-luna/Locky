import AppKit
import CryptoKit
import Foundation
import ImageIO
import LockyKit
import OpenDirectory
import OSLog
import UniformTypeIdentifiers

/// Renders the images of the Mac sent to the iPhone: wallpaper, user picture and the product image
/// of the paired iPhone. The image of the Mac itself is embedded in the iPhone (``MacCatalog``),
/// which draws the wallpaper in its screen.
@MainActor
enum MacImageRenderer {
    private nonisolated static let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "MacImages")

    /// Builds every image. `version` changes whenever one of them changes.
    /// - Parameter phoneModelIdentifier: Model of the paired iPhone ("iPhone18,1"), to render its picture.
    static func render(phoneModelIdentifier: String?) -> MacImages {
        let wallpaperData: Data? = currentWallpaper().flatMap { encode($0, maxPixelSize: MacImages.wallpaperPixelSize, opaque: true) }
        let pictureData: Data? = userPicture().flatMap { encode($0, maxPixelSize: MacImages.userPicturePixelSize, opaque: true) }
        let phoneData: Data? = phoneModelIdentifier.flatMap(phoneImage(modelIdentifier:)).flatMap {
            encode($0, maxPixelSize: MacImages.phonePixelSize, opaque: false)
        }
        var digest: SHA256 = .init()
        [wallpaperData, pictureData, phoneData].forEach { digest.update(data: $0 ?? Data()) }
        let version: String = digest.finalize().prefix(8).map { String($0, radix: 16) }.joined()
        return .init(version: version, wallpaper: wallpaperData, userPicture: pictureData, phone: phoneData)
    }

    /// Product image of an iPhone model, cropped to its visible pixels.
    static func phoneImage(modelIdentifier: String) -> CGImage? {
        var proposedRect: NSRect = .init(x: 0, y: 0, width: 512, height: 512)
        guard
            let icon = DeviceIcon.image(forModelIdentifier: modelIdentifier)?
                .cgImage(forProposedRect: &proposedRect, context: nil, hints: nil),
            let bitmap = ScreenLocator.Bitmap(image: icon),
            let opaque = bitmap.opaqueBounds
        else { return nil }
        return icon.cropping(to: opaque) ?? icon
    }

    /// URL of the wallpaper of the main screen, used to detect changes.
    static var wallpaperURL: URL? {
        wallpaperURL(for: NSScreen.main)
    }

    static func wallpaperURL(for screen: NSScreen?) -> URL? {
        screen.flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
    }

    // MARK: - Wallpaper

    /// Changes whenever the wallpaper of the main screen changes (file or content).
    static var wallpaperSignature: String {
        wallpaperSignature(for: NSScreen.main)
    }

    /// Changes whenever the wallpaper of `screen` changes (file or content), or becomes readable.
    static func wallpaperSignature(for screen: NSScreen?) -> String {
        let url: URL? = wallpaperURL(for: screen)
        // In a protected folder not asked for yet: even its attributes would make macOS ask.
        let isReadable: Bool = url.map(WallpaperAccess.mayRead) ?? true
        let modified: Date? = isReadable
            ? url.flatMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }
            : nil
        return [url?.path(percentEncoded: false) ?? "", modified?.description ?? "", isReadable ? "" : "not asked"]
            .joined(separator: "|")
    }

    /// Wallpaper of `screen` at its resolution, for the lock and unlock animations. Decoded off the
    /// main thread.
    static func screenWallpaper(for screen: NSScreen) async -> CGImage? {
        guard let url = wallpaperFileURL(for: screen) else { return nil }
        let largestSide: CGFloat = max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor
        return await decodeWallpaper(at: url, maxPixelSize: Int(largestSide))
    }

    private static func currentWallpaper() -> CGImage? {
        wallpaperFileURL(for: NSScreen.main).flatMap { decodeImage(at: $0, maxPixelSize: 1_600) }
    }

    /// Image file of the wallpaper (the most recent one for rotating wallpapers).
    private static func wallpaperFileURL(for screen: NSScreen?) -> URL? {
        // In a protected folder: never read before Locky explained why (see WallpaperAccess).
        guard let url = wallpaperURL(for: screen), WallpaperAccess.mayRead(url) else { return nil }
        guard url.hasDirectoryPath else { return url }
        // Rotating wallpapers: pick the most recently used image of the folder.
        let files: [URL] = (try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.contentAccessDateKey],
            options: .skipsHiddenFiles
        )) ?? []
        return files.max(by: { accessDate($0) < accessDate($1) })
    }

    @concurrent
    private nonisolated static func decodeWallpaper(at url: URL, maxPixelSize: Int) async -> CGImage? {
        decodeImage(at: url, maxPixelSize: maxPixelSize)
    }

    private nonisolated static func decodeImage(at url: URL, maxPixelSize: Int) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            logger.notice("Wallpaper not readable: \(url.path(percentEncoded: false))")
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    private static func accessDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentAccessDateKey]).contentAccessDate) ?? .distantPast
    }

    // MARK: - User picture

    /// Picture of the macOS user, from the directory service.
    static func userPicture() -> CGImage? {
        guard
            let node = try? ODNode(session: .default(), type: ODNodeType(kODNodeTypeLocalNodes)),
            let record = try? node.record(withRecordType: kODRecordTypeUsers, name: NSUserName(), attributes: [kODAttributeTypeJPEGPhoto, kODAttributeTypePicture])
        else { return nil }
        if let data = (try? record.values(forAttribute: kODAttributeTypeJPEGPhoto))?.first as? Data,
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            return image
        }
        if let path = (try? record.values(forAttribute: kODAttributeTypePicture))?.first as? String,
           let image = NSImage(contentsOfFile: path) {
            return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        }
        return nil
    }

    // MARK: - Encoding

    /// JPEG for opaque images, PNG where transparency matters: decoded anywhere, extensions and
    /// Apple Watch included (a device may not decode HEIC in an extension).
    static func encode(_ image: CGImage, maxPixelSize: Int, opaque: Bool) -> Data? {
        let scaled: CGImage = resize(image, maxPixelSize: maxPixelSize) ?? image
        let data: NSMutableData = .init()
        let type: UTType = opaque ? .jpeg : .png
        guard let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else {
            return nil
        }
        // 0.7: no visible loss at the size the iPhone shows them, much smaller than 0.8 and above.
        let options: [CFString: Any] = opaque ? [kCGImageDestinationLossyCompressionQuality: 0.7] : [:]
        CGImageDestinationAddImage(destination, scaled, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return data as Data
    }

    private static func resize(_ image: CGImage, maxPixelSize: Int) -> CGImage? {
        let largest: Int = max(image.width, image.height)
        guard largest > maxPixelSize else { return image }
        let scale: CGFloat = CGFloat(maxPixelSize) / CGFloat(largest)
        let width: Int = .init(CGFloat(image.width) * scale)
        let height: Int = .init(CGFloat(image.height) * scale)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
