import SwiftUI

/// The brightness of the screen of a drawn Mac, at its top right, as macOS shows it while it
/// changes.
struct BrightnessIndicator: View {
    let level: Double

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width * 0.3
            let height: CGFloat = width * 0.2
            let symbol: CGFloat = height * 0.5
            let bar: CGFloat = width - height * 0.6 - symbol - height * 0.25
            HStack(spacing: height * 0.25) {
                Image(systemName: "sun.max.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: symbol, height: symbol)
                Capsule()
                    .fill(.white.opacity(0.25))
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(.white)
                            .frame(width: max(height * 0.22, bar * level))
                    }
                    .frame(width: bar, height: height * 0.22)
            }
            .foregroundStyle(.white)
            .frame(width: width, height: height)
            .background(.black.opacity(0.45), in: .rect(cornerRadius: height * 0.35))
            .position(x: proxy.size.width - proxy.size.width * 0.03 - width / 2, y: proxy.size.height * 0.06 + height / 2)
        }
        .accessibilityHidden(true)
    }
}
