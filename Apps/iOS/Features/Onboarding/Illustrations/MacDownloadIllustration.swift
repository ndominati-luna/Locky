import SwiftUI

/// The Mac outline with a bouncing download arrow.
struct MacDownloadIllustration: View {
    var body: some View {
        MacOutline {
            Image(systemName: "arrow.down")
                .font(.largeTitle.bold())
                .symbolEffect(.bounce, options: .repeat(.periodic(delay: 1.2)))
        }
        .foregroundStyle(Color.brandArt)
        .accessibilityHidden(true)
    }
}
