import SwiftUI

/// No measurement yet: waves ripple out of an antenna, stars twinkle around, and a button starts
/// the first measurement.
struct WavesEmptyView: View {
    var startMeasurement: (() -> Void)?

    var body: some View {
        VStack(spacing: 22) {
            RippleIllustration()
                .frame(width: 220, height: 220)
            VStack(spacing: 10) {
                Text("No measurement yet")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                Text("Measure the waves around your Mac, at home, at work or anywhere: Wi-Fi, Bluetooth, sound… and see how they affect Locky.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            if let startMeasurement {
                Button("Measure the waves", systemImage: "dot.radiowaves.left.and.right", action: startMeasurement)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Rings leaving an antenna in the Locky blue, like waves on water.
private struct RippleIllustration: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private static let ringCount: Int = 5
    private static let period: Double = 3.6

    var body: some View {
        ZStack {
            TimelineView(.animation(paused: reduceMotion)) { timeline in
                let time: Double = timeline.date.timeIntervalSinceReferenceDate
                Canvas { context, size in
                    let center: CGPoint = .init(x: size.width / 2, y: size.height / 2)
                    let maximumRadius: CGFloat = min(size.width, size.height) / 2
                    for index in 0..<Self.ringCount {
                        let phase: Double = (time / Self.period + Double(index) / Double(Self.ringCount)).truncatingRemainder(dividingBy: 1)
                        let radius: CGFloat = 34 + (maximumRadius - 36) * phase
                        let rect: CGRect = .init(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
                        var ring: GraphicsContext = context
                        ring.opacity = 1 - phase * 0.85
                        ring.stroke(
                            Path(ellipseIn: rect),
                            with: .linearGradient(
                                Gradient(colors: [Color(red: 0.11, green: 0.84, blue: 1.0), Color(red: 0.12, green: 0.38, blue: 0.94)]),
                                startPoint: .init(x: rect.minX, y: rect.minY),
                                endPoint: .init(x: rect.maxX, y: rect.maxY)
                            ),
                            style: .init(lineWidth: 2.5 * (1 - phase) + 0.5)
                        )
                    }
                }
                .opacity(0.9)
            }
            .mask {
                RadialGradient(colors: [.black, .black, .clear], center: .center, startRadius: 0, endRadius: 110)
            }
            SparklesView(isActive: !reduceMotion)
                .padding(-10)
            Circle()
                .fill(.clear)
                .frame(width: 72, height: 72)
                .glassEffect(.regular.tint(Color(red: 0.12, green: 0.55, blue: 1.0).opacity(0.6)), in: .circle)
                .overlay {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.white)
                        .symbolEffect(.variableColor.iterative, options: .repeating, isActive: !reduceMotion)
                }
        }
        .accessibilityHidden(true)
    }
}
