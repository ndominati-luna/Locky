import LockyKit
import SwiftUI

extension LockAnimationStyle {
    var name: LocalizedStringKey {
        switch self {
        case .iris: "Iris"
        case .halo: "Halo"
        case .flight: "Flight"
        case .curtain: "Curtain"
        case .none: "No animation"
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
