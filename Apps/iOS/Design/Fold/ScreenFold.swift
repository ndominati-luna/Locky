import SwiftUI

/// The fold of the large screen of a foldable iPhone (iPhone Duo unfolded or half open).
///
/// The iPhone Duo folds like a book: the fold crosses the middle of the long side of its large
/// screen. iOS reports the hinge state (`UIHingeInteraction`) but not where the fold is, so it is
/// derived from the window, which always covers the whole screen on iPhone.
struct ScreenFold: Equatable {
    enum Orientation: Equatable {
        /// The fold is a vertical line: one page on the left, one on the right.
        case vertical
        /// The fold is a horizontal line: one page on top, one below (device turned like a laptop).
        case horizontal
    }

    var orientation: Orientation
    /// Distance from the leading (vertical fold) or top (horizontal fold) edge of the safe area to
    /// the fold. Two-page layouts span the safe area, so this is where they split.
    var offset: CGFloat

    /// Shortest side from which a screen is the large screen of a foldable: every iPhone screen,
    /// the outer screen of the Duo included, is narrower.
    static let minimumShortSide: CGFloat = 600

    /// The fold of a window of `windowSize` whose safe area starts at `safeAreaOrigin`, or `nil`
    /// when the app should lay out as on a regular iPhone.
    ///
    /// Held like a book (landscape), the large screen always shows two pages. Turned upright, it is
    /// one tall screen while flat, and two only when half open like a laptop (`isHalfOpen`).
    static func detect(windowSize: CGSize, safeAreaOrigin: CGPoint, isHalfOpen: Bool) -> ScreenFold? {
        guard min(windowSize.width, windowSize.height) >= minimumShortSide else { return nil }
        if windowSize.width >= windowSize.height {
            return .init(orientation: .vertical, offset: windowSize.width / 2 - safeAreaOrigin.x)
        }
        guard isHalfOpen else { return nil }
        return .init(orientation: .horizontal, offset: windowSize.height / 2 - safeAreaOrigin.y)
    }
}

extension EnvironmentValues {
    /// The fold of the screen when the app runs on the large screen of a foldable iPhone.
    @Entry var screenFold: ScreenFold?
}
