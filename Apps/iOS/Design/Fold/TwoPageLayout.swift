import SwiftUI

/// Lays out exactly two views, one on each side of the fold, never across it. Each view is
/// centered in its page, which it may fill.
///
/// The layout must span the safe area along the fold axis (it splits at ``ScreenFold/offset``).
struct TwoPageLayout: Layout {
    let fold: ScreenFold
    /// Free space around the fold.
    var gutter: CGFloat = 32
    /// The second page starts right on the fold (the whole gutter is taken from the first one), for
    /// a page whose background or edge marks the fold.
    var secondPageStartsAtFold: Bool = false

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        switch fold.orientation {
        case .vertical:
            let width: CGFloat = proposal.width ?? subviews.reduce(gutter) { $0 + $1.sizeThatFits(.unspecified).width }
            let pages: [CGRect] = pageRects(in: .init(x: 0, y: 0, width: width, height: proposal.height ?? 0))
            let height: CGFloat = zip(subviews, pages)
                .map { subview, page in subview.sizeThatFits(.init(width: page.width, height: proposal.height)).height }
                .max() ?? 0
            return .init(width: width, height: min(height, proposal.height ?? .infinity))
        case .horizontal:
            let height: CGFloat = proposal.height ?? subviews.reduce(gutter) { $0 + $1.sizeThatFits(.unspecified).height }
            let pages: [CGRect] = pageRects(in: .init(x: 0, y: 0, width: proposal.width ?? 0, height: height))
            let width: CGFloat = zip(subviews, pages)
                .map { subview, page in subview.sizeThatFits(.init(width: proposal.width, height: page.height)).width }
                .max() ?? 0
            return .init(width: min(width, proposal.width ?? .infinity), height: height)
        }
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        for (subview, page) in zip(subviews, pageRects(in: bounds)) {
            subview.place(at: .init(x: page.midX, y: page.midY), anchor: .center, proposal: .init(page.size))
        }
    }

    /// The two pages, leaving the gutter free around the fold.
    private func pageRects(in bounds: CGRect) -> [CGRect] {
        // Gutter before and after the fold.
        let before: CGFloat = secondPageStartsAtFold ? gutter : gutter / 2
        let after: CGFloat = gutter - before
        switch fold.orientation {
        case .vertical:
            let split: CGFloat = bounds.minX + min(max(fold.offset, bounds.width * 0.2), bounds.width * 0.8)
            return [
                .init(x: bounds.minX, y: bounds.minY, width: max(0, split - before - bounds.minX), height: bounds.height),
                .init(x: split + after, y: bounds.minY, width: max(0, bounds.maxX - split - after), height: bounds.height)
            ]
        case .horizontal:
            let split: CGFloat = bounds.minY + min(max(fold.offset, bounds.height * 0.2), bounds.height * 0.8)
            return [
                .init(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(0, split - before - bounds.minY)),
                .init(x: bounds.minX, y: split + after, width: bounds.width, height: max(0, bounds.maxY - split - after))
            ]
        }
    }
}
