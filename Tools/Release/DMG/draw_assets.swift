import AppKit

// Draws the DMG artwork: the window background (1x and 2x) and the volume icon, from the Locky
// glyph of the Mac app. Usage: swift draw_assets.swift <LockyGlyph.pdf> <output folder>
//
// The background is a Locky blue of medium luminance where Finder writes the names under the
// icons: Finder writes them in black in light mode and in white in dark mode, both stay readable.

let glyphURL = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
guard let glyph = NSImage(contentsOf: glyphURL) else { fatalError("No glyph at \(glyphURL.path)") }

/// Window content size in points; the icons are centered at x 165 and 495, y 200 (from the top).
let windowSize = CGSize(width: 660, height: 400)
let appCenter = CGPoint(x: 165, y: 200)
let applicationsCenter = CGPoint(x: 495, y: 200)

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    .init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

/// The glyph filled with a color.
func tinted(_ image: NSImage, _ fill: NSColor, size: CGSize) -> NSImage {
    NSImage(size: size, flipped: false) { rect in
        image.draw(in: rect)
        fill.set()
        rect.fill(using: .sourceAtop)
        return true
    }
}

func render(scale: CGFloat, _ draw: (CGContext, CGSize) -> Void, size: CGSize) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = size
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    draw(context, size)
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func save(_ rep: NSBitmapImageRep, _ name: String) {
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appending(path: name))
}

// MARK: - Background

func drawBackground(_ context: CGContext, _ size: CGSize) {
    // Top-left lighter, bottom-right deeper, like the app icon; around 0.18 of luminance on the
    // band of the names.
    let gradient = NSGradient(colors: [color(0x2C9BF0), color(0x2A74E6), color(0x2350CF)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
    gradient.draw(in: CGRect(origin: .zero, size: size), angle: -60)

    // Soft lights behind the two icons.
    for center in [appCenter, applicationsCenter] {
        let flipped = CGPoint(x: center.x, y: size.height - center.y)
        let glow = NSGradient(colors: [color(0xFFFFFF, 0.16), color(0xFFFFFF, 0)])!
        glow.draw(fromCenter: flipped, radius: 0, toCenter: flipped, radius: 118, options: [])
    }

    // The Locky wings, large and faint, spread over the window behind the icons.
    let watermarkWidth: CGFloat = 600
    let watermarkSize = CGSize(width: watermarkWidth, height: watermarkWidth * glyph.size.height / glyph.size.width)
    let watermark = tinted(glyph, .white, size: watermarkSize)
    watermark.draw(
        in: CGRect(x: (size.width - watermarkSize.width) / 2, y: (size.height - watermarkSize.height) / 2 - 10, width: watermarkSize.width, height: watermarkSize.height),
        from: .zero, operation: .sourceOver, fraction: 0.06
    )

    // The arrow from Locky to Applications: a gentle arc with a rounded head.
    let start = CGPoint(x: appCenter.x + 84, y: size.height - appCenter.y + 4)
    let end = CGPoint(x: applicationsCenter.x - 88, y: size.height - applicationsCenter.y + 4)
    let control = CGPoint(x: (start.x + end.x) / 2, y: start.y + 30)
    let arc = NSBezierPath()
    arc.move(to: start)
    arc.curve(to: end, controlPoint1: control, controlPoint2: control)
    arc.lineWidth = 7
    arc.lineCapStyle = .round
    color(0xFFFFFF, 0.92).setStroke()
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -2), blur: 6, color: color(0x0B2A7A, 0.35).cgColor)
    arc.stroke()
    // Head, along the end tangent of the arc.
    let angle = atan2(end.y - control.y, end.x - control.x)
    let head = NSBezierPath()
    let length: CGFloat = 22
    head.move(to: CGPoint(x: end.x - length * cos(angle - .pi / 5), y: end.y - length * sin(angle - .pi / 5)))
    head.line(to: end)
    head.line(to: CGPoint(x: end.x - length * cos(angle + .pi / 5), y: end.y - length * sin(angle + .pi / 5)))
    head.lineWidth = 7
    head.lineCapStyle = .round
    head.lineJoinStyle = .round
    head.stroke()
    context.restoreGState()
}

save(render(scale: 1, drawBackground, size: windowSize), "background.png")
save(render(scale: 2, drawBackground, size: windowSize), "background@2x.png")

// MARK: - Volume icon

/// A Locky external drive: the blue of the app icon with its wings, on a silver base.
func drawVolumeIcon(_ context: CGContext, _ size: CGSize) {
    let unit: CGFloat = size.width / 1024
    let body = CGRect(x: 160 * unit, y: 80 * unit, width: 704 * unit, height: 860 * unit)
    let radius: CGFloat = 92 * unit
    let shape = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10 * unit), blur: 24 * unit, color: color(0x000000, 0.28).cgColor)
    color(0xAEB2B9).setFill()
    shape.fill()
    context.restoreGState()

    // Blue face, lighter at the top like the app icon, then the silver base with its light.
    let baseHeight: CGFloat = 150 * unit
    let base = CGRect(x: body.minX, y: body.minY, width: body.width, height: baseHeight)
    context.saveGState()
    shape.addClip()
    NSGradient(colors: [color(0x1DD3FF), color(0x2161EE)])!.draw(in: CGRect(x: body.minX, y: base.maxY, width: body.width, height: body.height - baseHeight), angle: -90)
    NSGradient(colors: [color(0xF2F3F5), color(0xC9CCD2), color(0xAEB2B9)], atLocations: [0, 0.6, 1], colorSpace: .sRGB)!.draw(in: base, angle: -90)
    color(0x000000, 0.18).setFill()
    CGRect(x: body.minX, y: base.maxY - 2 * unit, width: body.width, height: 3 * unit).fill()
    // Highlight along the top edge of the face.
    NSGradient(colors: [color(0xFFFFFF, 0.35), color(0xFFFFFF, 0)])!.draw(in: CGRect(x: body.minX, y: body.maxY - 60 * unit, width: body.width, height: 60 * unit), angle: -90)
    context.restoreGState()
    let light = CGRect(x: body.maxX - 110 * unit, y: body.minY + baseHeight / 2 - 13 * unit, width: 34 * unit, height: 26 * unit)
    color(0xFFFFFF).setFill()
    NSBezierPath(ovalIn: light).fill()

    // The wings and padlock, white, centered on the blue face.
    let faceHeight = body.height - baseHeight
    let glyphWidth: CGFloat = 520 * unit
    let glyphSize = CGSize(width: glyphWidth, height: glyphWidth * glyph.size.height / glyph.size.width)
    let glyphRect = CGRect(x: body.midX - glyphSize.width / 2, y: base.maxY + (faceHeight - glyphSize.height) / 2, width: glyphSize.width, height: glyphSize.height)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -4 * unit), blur: 10 * unit, color: color(0x0B2A7A, 0.3).cgColor)
    tinted(glyph, .white, size: glyphSize).draw(in: glyphRect)
    context.restoreGState()
}

let iconset = out.appending(path: "VolumeIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let rep = render(scale: CGFloat(scale), drawVolumeIcon, size: CGSize(width: points, height: points))
        try! rep.representation(using: .png, properties: [:])!.write(to: iconset.appending(path: name))
    }
}
