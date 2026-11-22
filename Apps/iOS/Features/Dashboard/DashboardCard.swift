import SwiftUI

/// A glass card of the dashboard, in the style of a widget: a small title, then its content, over
/// an optional backdrop (the blurred artwork of the music playing).
struct DashboardCard<Content: View, Backdrop: View>: View {
    let title: LocalizedStringKey
    var icon: Image?
    /// The title in the primary color, while the card shows something live (a track playing).
    var isTitleProminent: Bool = false
    @ViewBuilder var content: Content
    @ViewBuilder var backdrop: Backdrop

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
            .foregroundStyle(isTitleProminent ? Color.primary : Color.secondary)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            backdrop
                .clipShape(.rect(cornerRadius: 26))
        }
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

extension DashboardCard where Backdrop == EmptyView {
    init(
        title: LocalizedStringKey,
        icon: Image? = nil,
        isTitleProminent: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, icon: icon, isTitleProminent: isTitleProminent, content: content) {
            EmptyView()
        }
    }
}
