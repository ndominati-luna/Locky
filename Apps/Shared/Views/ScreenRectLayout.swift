import LockyKit
import SwiftUI

/// Places its single subview inside a rectangle expressed in fractions of the available space
/// (the screen of the Mac image).
struct ScreenRectLayout: Layout {
    let rect: NormalizedRect
    /// Points the subview runs past the rectangle on every side: drawn behind the image of the Mac,
    /// a picture slips under its bezel, so the edge of the screen never shows a thread of what lies
    /// behind the Mac.
    var outset: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let frame: CGRect = rect.rect(in: bounds.size)
            .offsetBy(dx: bounds.minX, dy: bounds.minY)
            .insetBy(dx: -outset, dy: -outset)
        for subview in subviews {
            subview.place(at: frame.origin, proposal: .init(frame.size))
        }
    }
}
