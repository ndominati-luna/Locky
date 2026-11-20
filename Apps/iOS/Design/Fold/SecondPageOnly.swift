import SwiftUI

/// Keeps a bottom bar (buttons, page dots, warnings) on the second page when the fold is vertical,
/// instead of centering it on the fold. Unchanged elsewhere.
struct SecondPageOnly<Content: View>: View {
    @Environment(\.screenFold) private var fold
    @ViewBuilder var content: Content

    var body: some View {
        if let fold, fold.orientation == .vertical {
            TwoPageLayout(fold: fold, gutter: 48) {
                Color.clear
                    .frame(width: 0, height: 0)
                content
                    .frame(maxWidth: 420)
            }
        } else {
            content
        }
    }
}
