import SwiftUI

/// The iPhone talking to the Mac through smooth radio waves (the signal your body attenuates).
struct SignalIllustration: View {
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "iphone")
                .resizable()
                .scaledToFit()
                .fontWeight(.light)
                .frame(height: 96)
            Image(systemName: "wave.3.right")
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .frame(height: 64)
                .symbolEffect(.variableColor.iterative.dimInactiveLayers.nonReversing, options: .repeating.speed(0.6))
            MacOutline()
                .frame(maxWidth: 140)
        }
        .foregroundStyle(Color.brandArt)
        .accessibilityHidden(true)
    }
}
