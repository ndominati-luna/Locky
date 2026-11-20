import LockyKit
import SwiftUI

/// The Mac outline of the original Locky illustrations, with content centered in its screen.
struct MacOutline<ScreenContent: View>: View {
    /// Screen interior of the `MacBookOutline` drawing (measured on the vector artwork).
    static var screenRect: NormalizedRect {
        .init(x: 0.1354, y: 0.0674, width: 0.7292, height: 0.8043)
    }

    @ViewBuilder var screen: ScreenContent

    var body: some View {
        Image(.macBookOutline)
            .resizable()
            .scaledToFit()
            .overlay {
                ScreenRectLayout(rect: Self.screenRect) {
                    screen
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
    }
}

extension MacOutline where ScreenContent == EmptyView {
    init() {
        self.init { EmptyView() }
    }
}
