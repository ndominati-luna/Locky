import SwiftUI

/// Hairline along the fold, between the two pages of the large screen, fading out at both ends.
struct PageDivider: View {
    @Environment(\.displayScale) private var displayScale
    let orientation: ScreenFold.Orientation

    var body: some View {
        let isVertical: Bool = orientation == .vertical
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: .primary.opacity(0.3), location: 0.15),
                .init(color: .primary.opacity(0.3), location: 0.85),
                .init(color: .clear, location: 1)
            ],
            startPoint: isVertical ? .top : .leading,
            endPoint: isVertical ? .bottom : .trailing
        )
        .frame(width: isVertical ? 1 / displayScale : nil, height: isVertical ? nil : 1 / displayScale)
        .padding(isVertical ? .vertical : .horizontal, 16)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
