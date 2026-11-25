import Foundation
import ImageIO
import LockyKit
import SwiftUI
import UIKit

/// Images of the paired Mac fetched from iCloud: its wallpaper, user picture, and the product image
/// of this iPhone. The Mac itself comes from the catalog embedded in the app (``MacFrame``).
struct MacVisuals: Equatable {
    /// Wallpaper of the Mac (JPEG), drawn in its screen.
    var wallpaper: Data?
    var userPicture: Data?
    /// Product image of this iPhone, rendered by the Mac (iOS cannot draw it).
    var phone: Data?
    /// A small copy of the wallpaper for the blurred backgrounds, decoded on every redraw.
    private(set) var backgroundWallpaper: Data?
    /// The wallpaper decoded once, for the screen of the Mac.
    private(set) var wallpaperImage: UIImage?

    init(wallpaper: Data? = nil, userPicture: Data? = nil, phone: Data? = nil) {
        self.wallpaper = wallpaper
        self.userPicture = userPicture
        self.phone = phone
        backgroundWallpaper = wallpaper.flatMap { Self.thumbnail($0, maxPixelSize: 256, opaque: true) }
        wallpaperImage = wallpaper.flatMap(UIImage.init(data:))
    }

    static func stored() -> MacVisuals {
        .init(wallpaper: SharedStore.wallpaper, userPicture: SharedStore.userPicture, phone: SharedStore.phoneImage)
    }

    func store() {
        SharedStore.wallpaper = wallpaper
        SharedStore.userPicture = userPicture
        SharedStore.phoneImage = phone
    }

    /// How the renditions are drawn: raised when it changes, for those an earlier version stored to
    /// be drawn again (``needsRenditions``). 2: drawn with Core Graphics, see ``render(_:wallpaper:width:)``.
    private static let drawing: Int = 2
    private static let drawingKey: String = "locky.renditionsDrawing"

    /// What the widgets and the Live Activity display (see ``SharedStore/Rendition``): the Mac with
    /// its wallpaper on screen, at the size they show it (the large widget about 230 points wide,
    /// the Live Activity 92: iOS refuses a Live Activity whose images exceed their place).
    @MainActor
    func storeRenditions(frame: MacFrame?) {
        UserDefaults.standard.set(Self.drawing, forKey: Self.drawingKey)
        SharedStore.deviceScreen = frame?.screen
        let renditions: [(SharedStore.Rendition, Data?)] = [
            (.widgetDevice, frame.flatMap { Self.render($0, wallpaper: wallpaperImage, width: 690) }),
            (.activityDevice, frame.flatMap { Self.render($0, wallpaper: wallpaperImage, width: 280) }),
            (.widgetWallpaper, backgroundWallpaper),
            (.activityWallpaper, wallpaper.flatMap { Self.thumbnail($0, maxPixelSize: 160, opaque: true) }),
            (.userPicture, userPicture.flatMap { Self.thumbnail($0, maxPixelSize: 96, opaque: true) })
        ]
        for (rendition, data) in renditions {
            SharedStore.setRendition(rendition, data)
        }
    }

    /// The renditions are missing, or drawn by an earlier version of Locky.
    var needsRenditions: Bool {
        SharedStore.rendition(.activityDevice) == nil || UserDefaults.standard.integer(forKey: Self.drawingKey) < Self.drawing
    }

    /// The Mac with its wallpaper on screen, `width` pixels wide (PNG: transparent around the Mac),
    /// as ``MacDeviceImage`` shows it: black behind the transparent screen of the picture, the
    /// wallpaper filling it, a pixel under the bezel all around.
    ///
    /// Drawn with Core Graphics, not by SwiftUI: new images of the Mac mostly arrive in the
    /// background (its push, the Bluetooth link), where iOS forbids the graphics processor, and the
    /// renderer of SwiftUI then left an empty picture, which the Live Activity showed as a void.
    private static func render(_ frame: MacFrame, wallpaper: UIImage?, width: CGFloat) -> Data? {
        let picture: UIImage = frame.image
        let size: CGSize = .init(
            width: width,
            height: (width * picture.size.height / max(picture.size.width, 1)).rounded()
        )
        let format: UIGraphicsImageRendererFormat = .init()
        format.scale = 1
        format.opaque = false
        let image: UIImage = UIGraphicsImageRenderer(size: size, format: format).image { context in
            if let screen = frame.screen {
                let rect: CGRect = screen.rect(in: size).insetBy(dx: -1, dy: -1)
                context.cgContext.saveGState()
                context.cgContext.clip(to: rect)
                UIColor.black.setFill()
                context.fill(rect)
                if let wallpaper {
                    // Scaled to fill the screen, centred, as `scaledToFill()`.
                    let scale: CGFloat = max(rect.width / max(wallpaper.size.width, 1), rect.height / max(wallpaper.size.height, 1))
                    let drawn: CGSize = .init(width: wallpaper.size.width * scale, height: wallpaper.size.height * scale)
                    wallpaper.draw(in: CGRect(
                        x: rect.midX - drawn.width / 2,
                        y: rect.midY - drawn.height / 2,
                        width: drawn.width,
                        height: drawn.height
                    ))
                }
                context.cgContext.restoreGState()
            }
            picture.draw(in: CGRect(origin: .zero, size: size))
        }
        return image.pngData()
    }

    private static func thumbnail(_ data: Data, maxPixelSize: Int, opaque: Bool) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let uiImage: UIImage = .init(cgImage: image)
        return opaque ? uiImage.jpegData(compressionQuality: 0.85) : uiImage.pngData()
    }
}
