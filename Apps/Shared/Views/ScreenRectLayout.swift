import LockyKit
import SwiftUI

/// Places its single subview inside a rectangle expressed in fractions of the available space
/// (the screen of the Mac image).
struct ScreenRectLayout: Layout {
    let rect: NormalizedRect

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frame: CGRect = rect.rect(in: bounds.size).offsetBy(dx: bounds.minX, dy: bounds.minY)
        for subview in subviews {
            subview.place(at: frame.origin, proposal: .init(frame.size))
        }
    }
}
