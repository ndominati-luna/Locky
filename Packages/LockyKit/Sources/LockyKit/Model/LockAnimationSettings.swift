import Foundation

/// How the Mac goes to its lock screen.
public enum LockAnimationStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// The desktop fades into its wallpaper, then an iris closes on the ring of the logo.
    case iris
    /// The wallpaper melts into the background while the logo appears in a glow.
    case halo
    /// The logo flies in like a bird and lands in place; it takes off while unlocking.
    case flight
    /// Two panels slide over the desktop and meet behind the logo.
    case curtain
    /// The Mac locks at once; the wings still appear on the lock screen.
    case none

    public var id: Self {
        self
    }
}

/// How the text under the logo appears.
public enum LockTitleStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Glyph after glyph, each one rising, sharpening and fading in.
    case reveal
    /// Typed glyph after glyph behind a caret.
    case typewriter
    /// The glyphs come together from far apart.
    case gather
    /// The title fades in, then a light sweeps across it.
    case shimmer

    public var id: Self {
        self
    }
}

/// Behind the logo of the animation, instead of black.
public enum LockBackgroundKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case color
    /// The wallpaper of each display, blurred and darkened.
    case wallpaper
    /// An image chosen on the Mac.
    case image

    public var id: Self {
        self
    }
}

/// The lock animation of the Mac, set on the Mac or from the iPhone
/// (``LockyMessage/lockAnimation(_:)``).
public struct LockAnimationSettings: Codable, Sendable, Equatable {
    public var style: LockAnimationStyle
    /// Text under the logo; empty for "Locky".
    public var title: String
    public var titleStyle: LockTitleStyle
    public var backgroundKind: LockBackgroundKind
    /// Color of the background, `RRGGBB`.
    public var backgroundColor: String
    /// The Mac has an image for the background (it is chosen on the Mac).
    public var hasBackgroundImage: Bool

    /// Longest text under the logo.
    public static let maximumTitleLength: Int = 24

    public init(
        style: LockAnimationStyle,
        title: String,
        titleStyle: LockTitleStyle,
        backgroundKind: LockBackgroundKind,
        backgroundColor: String,
        hasBackgroundImage: Bool
    ) {
        self.style = style
        self.title = title
        self.titleStyle = titleStyle
        self.backgroundKind = backgroundKind
        self.backgroundColor = backgroundColor
        self.hasBackgroundImage = hasBackgroundImage
    }

    private enum CodingKeys: String, CodingKey {
        case style
        case title
        case titleStyle
        case backgroundKind
        case backgroundColor
        case hasBackgroundImage
    }

    /// A newer peer may send a style this version does not know: the defaults stand in for it.
    public init(from decoder: any Decoder) throws {
        let container: KeyedDecodingContainer<CodingKeys> = try decoder.container(keyedBy: CodingKeys.self)
        style = (try? container.decode(LockAnimationStyle.self, forKey: .style)) ?? .iris
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        titleStyle = (try? container.decode(LockTitleStyle.self, forKey: .titleStyle)) ?? .reveal
        backgroundKind = (try? container.decode(LockBackgroundKind.self, forKey: .backgroundKind)) ?? .color
        backgroundColor = (try? container.decode(String.self, forKey: .backgroundColor)) ?? "000000"
        hasBackgroundImage = (try? container.decode(Bool.self, forKey: .hasBackgroundImage)) ?? false
    }
}
