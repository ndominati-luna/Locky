import AppKit

// Draws the DMG artwork: the window background (1x and 2x) and the volume icon, from the Locky
// glyph of the Mac app and the illustrations of the iPhone app (stars, steps, thief).
// Usage: swift draw_assets.swift <LockyGlyph.pdf> <output folder> <repository root>
//
// The background is a Locky blue of medium luminance where Finder writes the names under the
// icons: Finder writes them in black in light mode and in white in dark mode, both stay readable.

let glyphURL = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
guard let glyph = NSImage(contentsOf: glyphURL) else { fatalError("No glyph at \(glyphURL.path)") }
let root = URL(fileURLWithPath: CommandLine.arguments[3])

/// An illustration of the apps, by its image set name.
func illustration(_ name: String) -> NSImage {
    let folders = ["Apps/iOS/Resources/Assets.xcassets/Illustrations", "Apps/SharedBrand/StoryAssets.xcassets", "Legacy/Locky/Images.xcassets"]
    for folder in folders {
        let url = root.appending(path: "\(folder)/\(name).imageset/\(name).pdf")
        if let image = NSImage(contentsOf: url) { return image }
    }
    fatalError("No illustration \(name)")
}

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

    // The Locky wings, large and faint, spread over the window behind the icons.
    let watermarkWidth: CGFloat = 600
    let watermarkSize = CGSize(width: watermarkWidth, height: watermarkWidth * glyph.size.height / glyph.size.width)
    let watermark = tinted(glyph, .white, size: watermarkSize)
    watermark.draw(
        in: CGRect(x: (size.width - watermarkSize.width) / 2, y: (size.height - watermarkSize.height) / 2 - 10, width: watermarkSize.width, height: watermarkSize.height),
        from: .zero, operation: .sourceOver, fraction: 0.06
    )

    // Locky on an iPhone, Applications on a MacBook: the app goes from one to the other.
    drawIPhone(context, size)
    drawMacBook(context, size)

    // Soft lights behind the two icons, as if their screens were lit.
    for center in [appCenter, applicationsCenter] {
        let flipped = CGPoint(x: center.x, y: size.height - center.y)
        let glow = NSGradient(colors: [color(0xFFFFFF, 0.16), color(0xFFFFFF, 0)])!
        glow.draw(fromCenter: flipped, radius: 0, toCenter: flipped, radius: 110, options: [])
    }

    drawStars(size)
    drawSteps(size)
    drawThief(size)
    drawArrow(context, size)
}

/// A rectangle given from the top left of the window.
func fromTop(_ rect: CGRect, in size: CGSize) -> CGRect {
    CGRect(x: rect.minX, y: size.height - rect.maxY, width: rect.width, height: rect.height)
}

/// Line art like the illustrations of the apps: white strokes, the screen barely lighter than the
/// background so that Finder writes the name of the icon on it, in black or white, readably.
func strokeDevice(_ context: CGContext, _ path: CGPath, lineWidth: CGFloat, alpha: CGFloat = 0.9) {
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 4, color: color(0x0B2A7A, 0.3).cgColor)
    context.addPath(path)
    context.setStrokeColor(color(0xFFFFFF, alpha).cgColor)
    context.setLineWidth(lineWidth)
    context.strokePath()
    context.restoreGState()
}

func fill(_ context: CGContext, _ path: CGPath, _ fill: NSColor) {
    context.addPath(path)
    context.setFillColor(fill.cgColor)
    context.fillPath()
}

/// The iPhone holding the Locky icon on its screen.
func drawIPhone(_ context: CGContext, _ size: CGSize) {
    let body = fromTop(CGRect(x: appCenter.x - 78, y: 36, width: 156, height: 328), in: size)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 30, cornerHeight: 30, transform: nil)
    let screen = body.insetBy(dx: 8, dy: 8)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: 23, cornerHeight: 23, transform: nil)
    fill(context, bodyPath, color(0x0B2A7A, 0.16))
    fill(context, screenPath, color(0xFFFFFF, 0.06))
    strokeDevice(context, screenPath, lineWidth: 1, alpha: 0.3)
    strokeDevice(context, bodyPath, lineWidth: 3.5)
    // Dynamic Island.
    let island = fromTop(CGRect(x: appCenter.x - 19, y: 54, width: 38, height: 11), in: size)
    fill(context, CGPath(roundedRect: island, cornerWidth: 5.5, cornerHeight: 5.5, transform: nil), color(0xFFFFFF, 0.85))
    // Buttons on the sides.
    for button in [CGRect(x: body.minX - 3.5, y: 0, width: 2.5, height: 22), CGRect(x: body.minX - 3.5, y: 0, width: 2.5, height: 34), CGRect(x: body.maxX + 1, y: 0, width: 2.5, height: 48)] {
        let top: CGFloat = button.minX < body.minX ? (button.height == 22 ? 96 : 130) : 118
        let rect = fromTop(CGRect(x: button.minX, y: top, width: button.width, height: button.height), in: size)
        fill(context, CGPath(roundedRect: rect, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil), color(0xFFFFFF, 0.85))
    }
}

/// The MacBook holding the Applications folder on its screen.
func drawMacBook(_ context: CGContext, _ size: CGSize) {
    let lid = fromTop(CGRect(x: applicationsCenter.x - 133, y: 94, width: 266, height: 212), in: size)
    let lidPath = CGPath(roundedRect: lid, cornerWidth: 13, cornerHeight: 13, transform: nil)
    // The screen, with its chin at the bottom.
    let screen = fromTop(CGRect(x: lid.minX + 9, y: 103, width: 248, height: 189), in: size)
    let screenPath = CGPath(roundedRect: screen, cornerWidth: 6, cornerHeight: 6, transform: nil)
    fill(context, lidPath, color(0x0B2A7A, 0.16))
    fill(context, screenPath, color(0xFFFFFF, 0.06))
    strokeDevice(context, screenPath, lineWidth: 1, alpha: 0.3)
    strokeDevice(context, lidPath, lineWidth: 3.5)
    // The notch of the camera.
    let notch = fromTop(CGRect(x: applicationsCenter.x - 17, y: 101, width: 34, height: 9), in: size)
    fill(context, CGPath(roundedRect: notch, cornerWidth: 4, cornerHeight: 4, transform: nil), color(0xFFFFFF, 0.85))
    // The base, wider than the lid, with the groove to open it.
    let base = fromTop(CGRect(x: applicationsCenter.x - 158, y: 306, width: 316, height: 11), in: size)
    let basePath = CGMutablePath()
    basePath.addRoundedRect(in: base, cornerWidth: 5, cornerHeight: 5)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 4, color: color(0x0B2A7A, 0.3).cgColor)
    fill(context, basePath, color(0xFFFFFF, 0.9))
    context.restoreGState()
    let groove = fromTop(CGRect(x: applicationsCenter.x - 26, y: 306, width: 52, height: 4), in: size)
    fill(context, CGPath(roundedRect: groove, cornerWidth: 2, cornerHeight: 2, transform: nil), color(0x2350CF, 0.55))
}

/// Draws `image` tinted white, centered at `center` (from the top left), `width` wide.
func place(_ image: NSImage, center: CGPoint, width: CGFloat, alpha: CGFloat, in size: CGSize, rotation: CGFloat = 0) {
    let height = width * image.size.height / image.size.width
    let tinted = tinted(image, .white, size: CGSize(width: width, height: height))
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: size.height - center.y)
    transform.rotate(byDegrees: rotation)
    transform.concat()
    tinted.draw(in: CGRect(x: -width / 2, y: -height / 2, width: width, height: height), from: .zero, operation: .sourceOver, fraction: alpha)
    NSGraphicsContext.restoreGraphicsState()
}

/// The sparkles of the onboarding, scattered in the sky around the iPhone and the MacBook.
func drawStars(_ size: CGSize) {
    let stars: [(name: String, x: CGFloat, y: CGFloat, width: CGFloat, alpha: CGFloat)] = [
        ("BigStar4", 604, 50, 40, 0.75),
        ("Star4", 298, 56, 28, 0.6),
        ("Star4", 418, 40, 20, 0.5),
        ("Star4", 572, 22, 14, 0.4),
        ("Star4", 42, 76, 24, 0.55),
        ("Star4", 34, 302, 18, 0.4),
        ("Star4", 288, 128, 15, 0.35),
        ("Star4", 642, 168, 18, 0.5),
        ("Star4", 352, 26, 14, 0.35),
    ]
    for star in stars {
        place(illustration(star.name), center: CGPoint(x: star.x, y: star.y), width: star.width, alpha: star.alpha, in: size)
    }
}

/// Small steps under the arrow, from the iPhone to the MacBook, the oldest fainter.
func drawSteps(_ size: CGSize) {
    let left = illustration("StepLeft")
    let right = illustration("StepRight")
    let count = 6
    for index in 0..<count {
        let progress = CGFloat(index) / CGFloat(count - 1)
        let isLeft = index.isMultiple(of: 2)
        let x = appCenter.x + 98 + progress * 78
        // The left foot on the left of the way (above it, walking to the right).
        let y: CGFloat = appCenter.y + 26 + (isLeft ? -5 : 5)
        place(isLeft ? left : right, center: CGPoint(x: x, y: y), width: 17, alpha: 0.2 + 0.35 * progress, in: size, rotation: isLeft ? 5 : -5)
    }
}

/// The thief of the intrusion reports, peeking over the MacBook.
func drawThief(_ size: CGSize) {
    place(illustration("ThiefHat"), center: CGPoint(x: applicationsCenter.x, y: 70), width: 64, alpha: 0.65, in: size)
}

/// The way from the iPhone to the MacBook: a straight line, a hairline where it leaves the iPhone,
/// thicker and brighter as it goes, ending on a swept head.
func drawArrow(_ context: CGContext, _ size: CGSize) {
    let y = size.height - appCenter.y
    let start = CGPoint(x: appCenter.x + 92, y: y)
    let tip = CGPoint(x: applicationsCenter.x - 144, y: y)
    let headLength: CGFloat = 20
    let headHalfWidth: CGFloat = 11
    let notch: CGFloat = 6
    let base = CGPoint(x: tip.x - headLength, y: y)

    // The line, from a hairline to the neck of the head, which it enters.
    let neck = base.x + notch + 1
    let line = CGMutablePath()
    line.move(to: CGPoint(x: start.x, y: y + 0.4))
    line.addLine(to: CGPoint(x: neck, y: y + 2.8))
    line.addLine(to: CGPoint(x: neck, y: y - 2.8))
    line.addLine(to: CGPoint(x: start.x, y: y - 0.4))
    line.closeSubpath()

    // The head: a tip, two swept wings and a notch at the back.
    let head = CGMutablePath()
    head.move(to: tip)
    head.addLine(to: CGPoint(x: base.x - 2, y: y + headHalfWidth))
    head.addLine(to: CGPoint(x: base.x + notch, y: y))
    head.addLine(to: CGPoint(x: base.x - 2, y: y - headHalfWidth))
    head.closeSubpath()

    // A soft light around it, then a shade beneath for depth.
    context.saveGState()
    context.setShadow(offset: .zero, blur: 14, color: color(0xFFFFFF, 0.45).cgColor)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    context.setShadow(offset: CGSize(width: 0, height: -2), blur: 5, color: color(0x0B2A7A, 0.35).cgColor)
    context.beginTransparencyLayer(auxiliaryInfo: nil)
    // The line fades in from the iPhone: a gradient clipped to its outline.
    context.saveGState()
    context.addPath(line)
    context.clip()
    let fade = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(0xFFFFFF, 0.1).cgColor, color(0xFFFFFF, 0.6).cgColor, color(0xFFFFFF, 0.97).cgColor] as CFArray,
        locations: [0, 0.45, 1]
    )!
    context.drawLinearGradient(fade, start: start, end: CGPoint(x: neck, y: y), options: [.drawsAfterEndLocation])
    context.restoreGState()
    // Rounded corners on the head: filled and outlined with round joins.
    context.addPath(head)
    context.setFillColor(color(0xFFFFFF, 0.97).cgColor)
    context.setStrokeColor(color(0xFFFFFF, 0.97).cgColor)
    context.setLineWidth(3)
    context.setLineJoin(.round)
    context.drawPath(using: .fillStroke)
    context.endTransparencyLayer()
    context.endTransparencyLayer()
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
