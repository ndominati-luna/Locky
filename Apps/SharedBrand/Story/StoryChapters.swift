import SwiftUI

/// What follows the film: Locky then and now, its timeline and a thank-you.
struct StoryChapters: View {
    var body: some View {
        VStack(spacing: 20) {
            ThenAndNowCard()
            StoryTimeline()
            StoryFooter()
                .padding(.top, 8)
        }
    }
}

/// Footprints walking off, as in the first Locky, and a thank-you.
struct StoryFooter: View {
    var body: some View {
        VStack(spacing: 14) {
            StoryFootsteps()
            Text("Thanks for being part of the trip.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
    }
}

/// Footprints of the first Locky, walking off to the right: the very idea of Locky.
struct StoryFootsteps: View {
    var count: Int = 5
    var width: CGFloat = 22

    var body: some View {
        HStack(spacing: width * 0.45) {
            ForEach(0..<count, id: \.self) { index in
                Image(index.isMultiple(of: 2) ? .stepLeft : .stepRight)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width)
                    .offset(y: index.isMultiple(of: 2) ? -width * 0.27 : width * 0.27)
                    .opacity(0.35 + 0.6 * Double(index) / Double(max(count - 1, 1)))
            }
        }
        .foregroundStyle(.white)
        .accessibilityHidden(true)
    }
}

/// The blue of the original Locky, from cyan to deep blue, under twinkling stars.
struct StoryBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.78, blue: 0.98),
                    Color.lockyBlue,
                    Color(red: 0.04, green: 0.24, blue: 0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            SparklesView()
                .foregroundStyle(.white)
                .opacity(0.5)
                .padding(24)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}
