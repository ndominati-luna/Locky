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

    /// What the widgets and the Live Activity display (see ``SharedStore/Rendition``): the Mac with
    /// its wallpaper on screen, at the size they show it (the large widget about 230 points wide,
    /// the Live Activity 92: iOS refuses a Live Activity whose images exceed their place).
    @MainActor
    func storeRenditions(frame: MacFrame?) {
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

    /// The renditions are missing (images stored by an earlier version of Locky).
    var needsRenditions: Bool {
        SharedStore.rendition(.activityDevice) == nil
    }

    /// The Mac with its wallpaper on screen, `width` pixels wide (PNG: transparent around the Mac).
    @MainActor
    private static func render(_ frame: MacFrame, wallpaper: UIImage?, width: CGFloat) -> Data? {
        let height: CGFloat = (width * frame.image.size.height / max(frame.image.size.width, 1)).rounded()
        let renderer: ImageRenderer = .init(
            content: MacDeviceImage(frame: frame, family: .unknown, wallpaper: wallpaper)
                .frame(width: width, height: height)
        )
        renderer.scale = 1
        renderer.isOpaque = false
        return renderer.uiImage?.pngData()
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
