import SwiftUI

/// Illustration and explanation of a setup screen (onboarding, pairing, first try).
///
/// On iPhone: one scrolling column. On the large screen of a foldable iPhone: the illustration on
/// the first page, the explanation and its buttons on the second, nothing across the fold.
struct StepLayout<Art: View, Details: View>: View {
    @Environment(\.screenFold) private var fold
    /// Margins of the single column (iPhone).
    var columnPadding: EdgeInsets = .init(top: 72, leading: 32, bottom: 32, trailing: 32)
    @ViewBuilder var art: Art
    @ViewBuilder var details: Details

    var body: some View {
        if let fold {
            TwoPageLayout(fold: fold, gutter: 48) {
                CenteredPage {
                    art
                        .frame(maxWidth: 380)
                }
                CenteredPage {
                    VStack(spacing: 28) {
                        details
                    }
                    .frame(maxWidth: 420)
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 28) {
                    art
                    details
                }
                .padding(columnPadding)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}
