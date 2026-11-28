import Foundation
import Testing
@testable import LockyKit

struct LockAnimationTimingTests {
    /// The session locks once the animation covers the screen, well before the logo and its title
    /// are done: they play above the lock screen.
    @Test(arguments: LockAnimationStyle.allCases.filter { $0 != .none }, LockTitleStyle.allCases)
    func locksOnceCoveredBeforeTheEnd(style: LockAnimationStyle, titleStyle: LockTitleStyle) {
        let animation: LockAnimation = .init(
            style: style,
            title: "Locky",
            titleStyle: titleStyle,
            background: .init(kind: .color, colorHex: "#000000")
        )
        #expect(style.coverDuration > 0)
        // The margin of the Mac, then a whole second of logo at least.
        #expect(style.coverDuration + 0.15 + 1 < animation.lockDuration)
    }

    @Test func noAnimationLocksAtOnce() {
        #expect(LockAnimationStyle.none.coverDuration == 0)
    }
}
