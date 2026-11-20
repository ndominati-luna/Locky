import SwiftUI

/// Reveals a text glyph after glyph: each one rises a little, sharpens and fades in.
struct GlyphRevealRenderer: TextRenderer, Animatable {
    /// From 0 (hidden) to 1 (shown).
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let glyphs: [Text.Layout.RunSlice] = layout.flatMap { line in line.flatMap { run in Array(run) } }
        let count: Double = .init(max(1, glyphs.count))
        // Glyphs start one after the other over the first 60 %, each takes 40 % to appear.
        for (index, glyph) in glyphs.enumerated() {
            let start: Double = Double(index) / count * 0.6
            let local: Double = min(1, max(0, (progress - start) / 0.4))
            let eased: Double = 1 - pow(1 - local, 3)
            var copy: GraphicsContext = context
            copy.opacity = eased
            copy.addFilter(.blur(radius: (1 - eased) * 10))
            copy.translateBy(x: 0, y: (1 - eased) * 14)
            copy.draw(glyph)
        }
    }
}
