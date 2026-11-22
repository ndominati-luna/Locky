import SwiftUI

/// The logo of the 2015 Locky, from the seven pieces of its welcome screen: the feathers from the
/// top one down, then the padlock, one after the other. Then, every few seconds, the light that
/// ran through it back then: every piece dims to half and lights up again in turn, a tenth of a
/// second each (the timings of the 2015 storyboard).
struct LegacyLogoAssembly: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Pieces already in place, in the order of ``layers``.
    @State private var placedPieces: Int = 0
    /// While the light runs through the logo: the pieces it already lit.
    @State private var litPieces: Int?

    /// Six feathers, from the top one with the ring to the smallest, then the padlock.
    private static let layers: [ImageResource] = [
        .legacyLogo1, .legacyLogo2, .legacyLogo3, .legacyLogo4, .legacyLogo5, .legacyLogo6, .legacyLogo7
    ]
    private static let pieceDelay: Duration = .milliseconds(100)

    var body: some View {
        ZStack {
            ForEach(Self.layers.indices, id: \.self) { index in
                Image(Self.layers[index])
                    .resizable()
                    .scaledToFit()
                    .opacity(opacity(of: index))
                    .scaleEffect(index < placedPieces ? 1 : 0.7)
                    .offset(y: index < placedPieces ? 0 : -24)
            }
        }
        .task {
            guard !reduceMotion else {
                placedPieces = Self.layers.count
                return
            }
            for count in 1...Self.layers.count {
                withAnimation(.spring(duration: 0.4, bounce: 0.45)) { placedPieces = count }
                try? await Task.sleep(for: Self.pieceDelay)
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeOut(duration: 0.15)) { litPieces = 0 }
                try? await Task.sleep(for: .milliseconds(200))
                for count in 1...Self.layers.count {
                    withAnimation(.easeIn(duration: 0.1)) { litPieces = count }
                    try? await Task.sleep(for: Self.pieceDelay)
                }
                litPieces = nil
            }
        }
        .accessibilityHidden(true)
    }

    private func opacity(of index: Int) -> Double {
        guard index < placedPieces else { return 0 }
        guard let litPieces else { return 1 }
        return index < litPieces ? 1 : 0.5
    }
}
