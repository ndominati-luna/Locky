import SwiftUI

/// The logo of the 2015 Locky, then who made it and how the video was found.
struct StoryWords: View {
    /// Next to the film: a smaller logo.
    let isCompact: Bool

    var body: some View {
        VStack(spacing: isCompact ? 14 : 20) {
            LegacyLogoAssembly()
                .frame(height: isCompact ? 100 : 140)
            Text("Since \(String(LockyStory.releaseYear))")
                .font(.footnote.weight(.semibold).monospaced())
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .glassEffect(.regular, in: .capsule)
            Text("A wild ride with Tom and Nico")
                .font(.system(isCompact ? .title : .largeTitle, design: .rounded, weight: .bold))
            #if os(macOS)
            Text("You found it! \(LockyStory.tapCount) clicks, one for every year since the very first Locky.")
                .font(.headline)
            #else
            Text("You found it! \(LockyStory.tapCount) taps, one for every year since the very first Locky.")
                .font(.headline)
            #endif
            Text("Back in \(String(LockyStory.filmYear)), Tom and Nico dreamed of a Mac that locks itself when you walk away. Here is the video from back then.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .foregroundStyle(.white)
        .fixedSize(horizontal: false, vertical: true)
    }
}
