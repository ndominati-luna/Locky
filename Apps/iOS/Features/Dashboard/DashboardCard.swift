import SwiftUI

/// A glass card of the dashboard, in the style of a widget: a small title, then its content.
struct DashboardCard<Content: View>: View {
    let title: LocalizedStringKey
    var icon: Image?
    /// Color of the glass (artwork of the music playing…).
    var tint: Color?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                if let icon {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 15, height: 15)
                }
                Text(title)
                    .lineLimit(1)
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular.tint(tint?.opacity(0.35)), in: .rect(cornerRadius: 26))
    }
}
