import SwiftUI

/// Draws the title under the logo while it appears, in one of the ``LockTitleStyle``.
struct TitleRenderer: TextRenderer, Animatable {
    let style: LockTitleStyle
    /// From 0 (hidden) to 1 (shown).
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    /// Room for what the glyphs draw outside the text while they appear (blur, rise, glow, glyphs
    /// still far apart): SwiftUI clips a renderer to the text and this padding. Without it the
    /// tails of the rising glyphs were cut, then popped in as the title settled.
    var displayPadding: EdgeInsets {
        let side: CGFloat = style == .gather ? 240 : 32
        return .init(top: 32, leading: side, bottom: 48, trailing: side)
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        let glyphs: [Text.Layout.RunSlice] = layout.flatMap { line in line.flatMap { run in Array(run) } }
        guard !glyphs.isEmpty else { return }
        switch style {
        case .reveal: drawReveal(glyphs, in: context)
        case .typewriter: drawTypewriter(glyphs, in: context)
        case .gather: drawGather(glyphs, in: context)
        case .shimmer: drawShimmer(glyphs, in: context)
        }
    }

    /// Glyphs start one after the other over the first 60 %, each one takes 40 % to rise, sharpen
    /// and fade in.
    private func drawReveal(_ glyphs: [Text.Layout.RunSlice], in context: GraphicsContext) {
        let count: Double = .init(glyphs.count)
        for (index, glyph) in glyphs.enumerated() {
            let start: Double = Double(index) / count * 0.6
            let eased: Double = Self.easeOut((progress - start) / 0.4)
            guard eased > 0 else { continue }
            var copy: GraphicsContext = context
            copy.opacity = eased
            if eased < 1 {
                copy.addFilter(.blur(radius: (1 - eased) * 10))
                copy.translateBy(x: 0, y: (1 - eased) * 14)
            }
            copy.draw(glyph)
        }
    }

    /// Typed in the first 75 %, then the caret blinks twice and leaves. Nothing before it starts.
    private func drawTypewriter(_ glyphs: [Text.Layout.RunSlice], in context: GraphicsContext) {
        guard progress > 0 else { return }
        let typing: Double = min(1, progress / 0.75)
        let typed: Int = min(glyphs.count, Int((typing * Double(glyphs.count)).rounded(.up)))
        for glyph in glyphs.prefix(typed) {
            context.draw(glyph)
        }
        // The caret follows the last glyph typed, at the height of the line.
        let line: CGRect = glyphs[0].typographicBounds.rect
        let x: CGFloat = typed == 0 ? line.minX : glyphs[typed - 1].typographicBounds.rect.maxX
        let caret: CGRect = .init(x: x + line.height * 0.06, y: line.minY + line.height * 0.12, width: max(2, line.height * 0.05), height: line.height * 0.8)
        let blink: Double = progress < 0.75 ? 1 : (sin((progress - 0.75) / 0.25 * .pi * 4 + .pi / 2) > 0 ? 1 : 0) * (1 - (progress - 0.75) / 0.25)
        guard blink > 0.01 else { return }
        var copy: GraphicsContext = context
        copy.opacity = blink
        copy.fill(Path(caret), with: .foreground)
    }

    /// The glyphs come together from far apart, sharpening and fading in.
    private func drawGather(_ glyphs: [Text.Layout.RunSlice], in context: GraphicsContext) {
        let eased: Double = Self.easeOut(progress)
        guard eased > 0 else { return }
        let bounds: CGRect = glyphs.reduce(glyphs[0].typographicBounds.rect) { $0.union($1.typographicBounds.rect) }
        for glyph in glyphs {
            var copy: GraphicsContext = context
            copy.opacity = min(1, eased * 1.4)
            if eased < 1 {
                let distance: CGFloat = glyph.typographicBounds.rect.midX - bounds.midX
                copy.addFilter(.blur(radius: (1 - eased) * 6))
                copy.translateBy(x: distance * 0.9 * (1 - eased), y: 0)
            }
            copy.draw(glyph)
        }
    }

    /// The title fades in dimmed, then a light sweeps across it from left to right, each glyph
    /// brightening as it passes.
    private func drawShimmer(_ glyphs: [Text.Layout.RunSlice], in context: GraphicsContext) {
        let fade: Double = Self.easeOut(progress / 0.4)
        guard fade > 0 else { return }
        let bounds: CGRect = glyphs.reduce(glyphs[0].typographicBounds.rect) { $0.union($1.typographicBounds.rect) }
        // The light enters before the first glyph and leaves after the last one.
        let sweep: Double = -0.25 + 1.5 * min(1, max(0, (progress - 0.3) / 0.7))
        for glyph in glyphs {
            let position: Double = bounds.width > 0 ? (glyph.typographicBounds.rect.midX - bounds.minX) / bounds.width : 0
            let passed: Double = min(1, max(0, (sweep - position) / 0.2 + 0.5))
            let light: Double = max(0, 1 - abs(sweep - position) / 0.14)
            var copy: GraphicsContext = context
            copy.opacity = fade * (0.55 + 0.45 * passed)
            if fade < 1 {
                copy.addFilter(.blur(radius: (1 - fade) * 6))
            }
            copy.draw(glyph)
            guard light > 0 else { continue }
            var glow: GraphicsContext = context
            glow.opacity = light * 0.9
            glow.addFilter(.blur(radius: 6))
            glow.draw(glyph)
        }
    }

    /// Cubic ease out, clamped to 0…1.
    private static func easeOut(_ value: Double) -> Double {
        let clamped: Double = min(1, max(0, value))
        return 1 - pow(1 - clamped, 3)
    }
}
