import AppKit
import LockyKit
import SwiftUI

// The animations themselves are in LockyKit, shared with the preview of the iPhone: here, what only
// the Mac has (names in its language, the background image chosen on it).

extension LockAnimationStyle {
    var name: LocalizedStringKey {
        switch self {
        case .iris: "Iris"
        case .halo: "Halo"
        case .flight: "Flight"
        case .curtain: "Curtain"
        case .none: "None"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .iris: "The desktop fades into its wallpaper, then an iris closes on the Locky logo."
        case .halo: "The wallpaper melts into the background while the logo appears in a glow."
        case .flight: "The Locky logo flies in like a bird and lands in place, then takes off when you come back."
        case .curtain: "Two panels slide over the desktop and meet behind the logo."
        case .none: "Your Mac locks at once. The wings still appear on the lock screen when your iPhone is near."
        }
    }
}

extension LockTitleStyle {
    var name: LocalizedStringKey {
        switch self {
        case .reveal: "Reveal"
        case .typewriter: "Typewriter"
        case .gather: "Gather"
        case .shimmer: "Shimmer"
        }
    }
}

extension LockBackgroundKind {
    var name: LocalizedStringKey {
        switch self {
        case .color: "Color"
        case .wallpaper: "Wallpaper"
        case .image: "Image"
        }
    }
}

extension LockBackground {
    /// What to draw, the image decoded once per version. Black when the image is missing.
    @MainActor
    var backdrop: LockBackdrop {
        switch kind {
        case .color: .color(Color(hex: colorHex))
        case .wallpaper: .wallpaper
        case .image: LockBackgroundImage.image(version: imageVersion).map { .image($0) } ?? .color(.black)
        }
    }
}

/// The background image chosen in the animation window, copied next to the preferences of Locky so
/// that it stays even if the original moves.
@MainActor
enum LockBackgroundImage {
    private static var cache: (version: Int, image: NSImage)?

    static var url: URL {
        URL.applicationSupportDirectory.appending(path: "Locky/LockBackground")
    }

    /// Copies the image at `source`; `false` when it is not an image Locky can read.
    static func store(from source: URL) -> Bool {
        let isScoped: Bool = source.startAccessingSecurityScopedResource()
        defer {
            if isScoped {
                source.stopAccessingSecurityScopedResource()
            }
        }
        guard let data = try? Data(contentsOf: source), NSImage(data: data) != nil else { return false }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            return false
        }
        cache = nil
        return true
    }

    static func image(version: Int) -> NSImage? {
        if let cache, cache.version == version {
            return cache.image
        }
        guard let image = NSImage(contentsOf: url) else { return nil }
        cache = (version, image)
        return image
    }
}
