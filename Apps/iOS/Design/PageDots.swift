import SwiftUI

/// Page indicator of the onboarding, in the brand color so it stays visible in Light Mode.
struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(Color.brandArt.opacity(index == current ? 1 : 0.3))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(current + 1) of \(count)"))
    }
}
