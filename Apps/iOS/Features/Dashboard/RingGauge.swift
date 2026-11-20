import SwiftUI

/// Circular gauge with a symbol in its center, like the gauges of widgets.
struct RingGauge: View {
    /// From 0 to 1.
    let value: Double
    let tint: Color
    let systemImage: String
    private let lineWidth: CGFloat = 6

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(value, 0), 1))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(lineWidth / 2)
        .animation(.smooth(duration: 0.8), value: value)
        .accessibilityHidden(true)
    }
}
