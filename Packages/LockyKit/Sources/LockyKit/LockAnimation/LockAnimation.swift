import SwiftUI

#if canImport(UIKit)
import UIKit

/// An image of the platform: the wallpaper of the Mac, an image for the background.
public typealias PlatformImage = UIImage

extension Image {
    public init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#else
import AppKit

/// An image of the platform: the wallpaper of the Mac, an image for the background.
public typealias PlatformImage = NSImage

extension Image {
    public init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#endif

/// Everything the lock and unlock animations of the Mac need. Played on the Mac, and previewed on
/// the iPhone when it chooses them.
public struct LockAnimation: Equatable, Sendable {
    public var style: LockAnimationStyle
    /// Shown under the Locky logo.
    public var title: String
    public var titleStyle: LockTitleStyle
    public var background: LockBackground

    public init(style: LockAnimationStyle, title: String, titleStyle: LockTitleStyle, background: LockBackground) {
        self.style = style
        self.title = title
        self.titleStyle = titleStyle
        self.background = background
    }

    /// From the start of the animation to the lock of the session: the logo, then its title, then
    /// a short pause to read it.
    public var lockDuration: TimeInterval {
        style.logoDelay + style.intro(flightDistance: 0).titleStart + titleStyle.duration + 0.55
    }
}

/// Timings shared by the animations.
public enum LockAnimationTiming {
    /// The desktop fades into the wallpaper.
    public static let fadeDuration: TimeInterval = 0.7
    /// The iris closes on the ring of the logo.
    public static let irisDuration: TimeInterval = 1.0
}

extension LockAnimationStyle {
    /// From the start of the animation to the appearance of the logo.
    public var logoDelay: TimeInterval {
        switch self {
        case .iris: LockAnimationTiming.fadeDuration + LockAnimationTiming.irisDuration * 0.7
        case .halo: 0.9
        case .flight: 0.15
        case .curtain: 1.0
        case .none: 0
        }
    }

    /// How the logo comes in; `flightDistance` is how far it starts, in sides of the logo.
    func intro(flightDistance: Double) -> LogoIntro {
        switch self {
        case .iris, .curtain, .none: .unfold
        case .halo: .materialize
        case .flight: .flyIn(distance: flightDistance)
        }
    }

    /// Unlocking, from the cover to the wallpaper (the overlays then fade into the desktop).
    public var unlockDuration: TimeInterval {
        switch self {
        case .iris: 1.4
        case .halo: 1.2
        case .flight, .curtain: 1.3
        case .none: 0
        }
    }
}

extension LockTitleStyle {
    /// How long the title takes to appear.
    public var duration: TimeInterval {
        switch self {
        case .reveal: 1.0
        case .typewriter: 1.1
        case .gather: 1.1
        case .shimmer: 1.5
        }
    }
}

/// Behind the logo instead of black, as chosen: the image itself stays on the Mac.
public struct LockBackground: Equatable, Sendable {
    public var kind: LockBackgroundKind
    /// `RRGGBB`.
    public var colorHex: String
    /// Changes with each image chosen on the Mac, so that the animation draws the new one.
    public var imageVersion: Int

    public init(kind: LockBackgroundKind, colorHex: String, imageVersion: Int = 0) {
        self.kind = kind
        self.colorHex = colorHex
        self.imageVersion = imageVersion
    }
}

/// A background ready to draw.
public enum LockBackdrop {
    case color(Color)
    /// The wallpaper of the display the animation plays on.
    case wallpaper
    case image(PlatformImage)
}

extension Color {
    /// A color from `RRGGBB`; black when it cannot be read.
    public init(hex: String) {
        let value: UInt64 = UInt64(hex.trimmingCharacters(in: .init(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// `RRGGBB` in sRGB.
    public var hex: String {
        let resolved: Color.Resolved = resolve(in: EnvironmentValues())
        return [resolved.red, resolved.green, resolved.blue]
            .map { component in
                let digits: String = .init(Int((min(1, max(0, component)) * 255).rounded()), radix: 16, uppercase: true)
                return digits.count < 2 ? "0" + digits : digits
            }
            .joined()
    }
}
