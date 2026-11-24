import SwiftUI

/// The Magic Keyboard with Touch ID on the desk in front of a Mac, with or without its numeric
/// keypad, in the colour of the Mac: Apple's own pictures, taken from macOS and seen from above
/// (`Tools/MacCatalog/make_keyboards.py`). Real measures, in centimetres.
enum DeskKeyboard: String {
    case compact
    case numpad

    static let depth: CGFloat = 11.49
    /// It slopes down toward the hands.
    static let backHeight: CGFloat = 1.09
    static let frontHeight: CGFloat = 0.41
    /// The radius of its corners in plan, as Apple's pictures show them.
    static let cornerRadius: CGFloat = 0.75
    /// The colours of the iMac; the keyboards sold on their own are silver.
    static let colours: Set<String> = ["Blue", "Green", "Orange", "Pink", "Purple", "Yellow"]

    var width: CGFloat {
        switch self {
        case .compact: 27.9
        case .numpad: 41.87
        }
    }

    /// The width it shows while two fingers spread it (`ratio` above 1) or close it: it follows
    /// them part of the way, between the two keyboards.
    func width(stretchedBy ratio: CGFloat) -> CGFloat {
        let wanted: CGFloat = width * (1 + (ratio - 1) * 0.6)
        return min(max(wanted, Self.compact.width * 0.94), Self.numpad.width * 1.04)
    }

    /// The keyboard the fingers leave: spread enough, the one with the numeric keypad; closed
    /// enough, the compact one; otherwise as it was.
    func settled(afterStretching ratio: CGFloat) -> Self {
        if ratio > 1.15 {
            return .numpad
        }
        if ratio < 0.87 {
            return .compact
        }
        return self
    }

    /// The keyboard of `colour` (as in ``colours``, silver otherwise).
    func image(colour: String) -> ImageResource {
        let colour: String = Self.colours.contains(colour) ? colour : "Silver"
        return .init(name: "Keyboard-\(self == .compact ? "Compact" : "Numpad")-\(colour)", bundle: .main)
    }

    /// The colour of the keyboard that comes with an iMac of the catalog, read from the name of its
    /// picture (`Mac-imac-2024-blue`); silver for the others.
    static func colour(ofAsset asset: String?) -> String {
        guard let last = asset?.split(separator: "-").last else { return "Silver" }
        let colour: String = last.capitalized
        return colours.contains(colour) ? colour : "Silver"
    }
}
