import SwiftUI

/// The Locky logo surrounded by stars: "the magic will happen soon".
struct MagicIllustration: View {
    @State private var isPulsing: Bool = false

    var body: some View {
        ZStack {
            SparklesView()
            Image(.lockyGlyph)
                .resizable()
                .scaledToFit()
                .padding(30)
                .scaleEffect(isPulsing ? 1.04 : 0.96)
                .animation(.easeInOut(duration: 1.4).repeatForever(), value: isPulsing)
        }
        .foregroundStyle(Color.brandArt)
        .onAppear { isPulsing = true }
        .accessibilityHidden(true)
    }
}
