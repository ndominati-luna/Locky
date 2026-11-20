import SwiftUI

/// One measure of the Mac, sized like a small widget: title and gauge, then the value and a detail.
struct MetricCard: View {
    let title: LocalizedStringKey
    let gauge: Double
    let tint: Color
    let systemImage: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                RingGauge(value: gauge, tint: tint, systemImage: systemImage)
                    .frame(width: 42, height: 42)
            }
            Spacer(minLength: 0)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .contentTransition(.numericText())
            Text(detail)
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 128, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
        .animation(.smooth, value: value)
        .accessibilityElement(children: .combine)
    }
}
