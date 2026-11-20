import SwiftUI

/// Content centered in its page, scrolling only when it does not fit (large Dynamic Type sizes).
struct CenteredPage<Content: View>: View {
    @ViewBuilder var content: Content
    @State private var height: CGFloat = 0

    var body: some View {
        ScrollView {
            content
                .padding(24)
                .frame(maxWidth: .infinity, minHeight: height)
        }
        .scrollBounceBehavior(.basedOnSize)
        .scrollIndicators(.hidden)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }
}
