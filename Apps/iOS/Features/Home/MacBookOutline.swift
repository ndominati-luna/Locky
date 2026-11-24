import SwiftUI
import UIKit

/// Where the parts of a MacBook are in its picture from the catalog, measured once from the
/// picture itself: every MacBook of macOS is drawn the same way, from the front and a little from
/// above. The lid is a rectangle down to its hinge; under it, the deck widens toward its front edge
/// (the perspective of the picture); the aluminium shows on that edge. Fractions of the picture.
struct MacBookOutline: Equatable {
    /// The sides of the lid, and how much its top is narrower at each end, for its rounded corners.
    let lidLeft: CGFloat
    let lidRight: CGFloat
    let lidTopInset: CGFloat
    /// The bottom of the lid, where it turns on the deck.
    let hinge: CGFloat
    /// The front edge of the deck, where the picture is widest, and the bottom of its face.
    let deckFront: CGFloat
    let deckBottom: CGFloat
    /// The top of the front edge of the shut lid (see ``lidEdge(of:outline:)``): its width, narrower
    /// for its rounded ends, and its colour, which the back of the lid carries on from.
    let edgeTopWidth: CGFloat
    let edgeTopRed: Double
    let edgeTopGreen: Double
    let edgeTopBlue: Double
    /// How much wider the front of the deck looks than the lid.
    let spread: CGFloat
    /// The colour of the aluminium, in sRGB.
    let red: Double
    let green: Double
    let blue: Double

    var aluminium: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    var edgeTop: Color {
        Color(.sRGB, red: edgeTopRed, green: edgeTopGreen, blue: edgeTopBlue)
    }

    /// Measured once per picture.
    @MainActor private static var cache: [String: MacBookOutline?] = [:]
    @MainActor private static var edges: [String: UIImage?] = [:]
    /// Where the front edge of the lid is taken from on the face of the deck: under its notch, and
    /// above its last rows, dark with the shadow on the desk. Shown a little taller, about as thick
    /// as the lid is next to the deck (4.5 mm over 10 mm on a MacBook Pro).
    static let edgeStart: CGFloat = 0.5
    static let edgeEnd: CGFloat = 0.86
    static let edgeThickness: CGFloat = 0.45

    /// The outline of a MacBook of the catalog, `nil` for another Mac or a picture it cannot read.
    @MainActor
    static func of(_ frame: MacFrame) -> MacBookOutline? {
        guard let asset = frame.asset, frame.screen != nil else { return nil }
        if let outline = cache[asset] {
            return outline
        }
        let outline: MacBookOutline? = measure(frame.image)
        cache[asset] = outline
        return outline
    }

    /// The front edge of the lid once it is shut, from the picture itself, so that it is of the
    /// same aluminium: the lower part of the face of the deck, under its notch, upside down, for its
    /// ends to round toward the back of the lid as those of the deck round toward the desk.
    @MainActor
    static func lidEdge(of frame: MacFrame, outline: MacBookOutline) -> UIImage? {
        guard let asset = frame.asset else { return nil }
        if let edge = edges[asset] {
            return edge
        }
        let edge: UIImage? = cutLidEdge(frame.image, outline: outline)
        edges[asset] = edge
        return edge
    }

    private static func cutLidEdge(_ image: UIImage, outline: MacBookOutline) -> UIImage? {
        guard let cgImage = image.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let height: CGFloat = CGFloat(cgImage.height)
        let top: Int = Int(((outline.deckFront + (outline.deckBottom - outline.deckFront) * edgeStart) * height).rounded())
        let bottom: Int = Int(((outline.deckFront + (outline.deckBottom - outline.deckFront) * edgeEnd) * height).rounded())
        guard
            bottom > top,
            let slice = cgImage.cropping(to: CGRect(x: 0, y: top, width: cgImage.width, height: bottom - top)),
            let context = CGContext(
                data: nil,
                width: slice.width,
                height: slice.height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { return nil }
        context.translateBy(x: 0, y: CGFloat(slice.height))
        context.scaleBy(x: 1, y: -1)
        context.draw(slice, in: CGRect(x: 0, y: 0, width: slice.width, height: slice.height))
        return context.makeImage().map { UIImage(cgImage: $0) }
    }

    /// Reads the outline from the transparency of the picture: the rows of the lid are all as wide,
    /// the first wider one is the hinge, the widest the front of the deck.
    private static func measure(_ image: UIImage) -> MacBookOutline? {
        guard let cgImage = image.cgImage, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let width: Int = cgImage.width
        let height: Int = cgImage.height
        guard width > 100, height > 100 else { return nil }
        var pixels: [UInt8] = .init(repeating: 0, count: width * height * 4)
        let isDrawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard isDrawn else { return nil }

        func alpha(_ x: Int, _ y: Int) -> UInt8 {
            pixels[(y * width + x) * 4 + 3]
        }
        /// The width of the opaque part of a row, and where it starts.
        func extent(_ y: Int) -> (left: Int, width: Int)? {
            guard
                let left = (0..<width).first(where: { alpha($0, y) > 128 }),
                let right = (0..<width).last(where: { alpha($0, y) > 128 })
            else { return nil }
            return (left, right - left + 1)
        }

        guard let lid = extent(height / 2) else { return nil }
        var rows: [(y: Int, width: Int)] = []
        for y in (height / 2)..<height {
            if let row = extent(y) {
                rows.append((y, row.width))
            }
        }
        guard
            let hinge = rows.first(where: { $0.width > lid.width + 2 })?.y,
            let widest = rows.filter({ $0.y >= hinge }).map(\.width).max(),
            let front = rows.first(where: { $0.y >= hinge && $0.width >= widest - 1 })?.y,
            let bottom = rows.last?.y,
            Double(hinge) > Double(height) * 0.6, front > hinge + 2, widest > lid.width + lid.width / 10
        else { return nil }

        // The front edge, clear of its shadow and of the notch in its middle.
        var sum: (red: Int, green: Int, blue: Int, count: Int) = (0, 0, 0, 0)
        let edgeRows: Range<Int> = (front + (bottom - front) / 4)..<(front + (bottom - front) * 3 / 5)
        for y in edgeRows {
            for x in Array(width * 15 / 100..<width * 35 / 100) + Array(width * 65 / 100..<width * 85 / 100) {
                let index: Int = (y * width + x) * 4
                guard pixels[index + 3] > 250 else { continue }
                sum.red += Int(pixels[index])
                sum.green += Int(pixels[index + 1])
                sum.blue += Int(pixels[index + 2])
                sum.count += 1
            }
        }
        guard sum.count > 0 else { return nil }
        let count: Double = Double(sum.count) * 255

        // The row the top of the edge of the lid comes from, upside down: its width and its colour,
        // clear of its rounded ends.
        let edgeTopRow: Int = min(bottom, max(front, Int((CGFloat(front) + CGFloat(bottom + 1 - front) * edgeEnd).rounded()) - 1))
        var top: (red: Int, green: Int, blue: Int, count: Int) = (0, 0, 0, 0)
        for y in max(front, edgeTopRow - 2)...edgeTopRow {
            for x in width * 20 / 100..<width * 80 / 100 {
                let index: Int = (y * width + x) * 4
                guard pixels[index + 3] > 250 else { continue }
                top.red += Int(pixels[index])
                top.green += Int(pixels[index + 1])
                top.blue += Int(pixels[index + 2])
                top.count += 1
            }
        }
        guard top.count > 0 else { return nil }
        let topCount: Double = Double(top.count) * 255

        return .init(
            lidLeft: CGFloat(lid.left) / CGFloat(width),
            lidRight: CGFloat(lid.left + lid.width) / CGFloat(width),
            lidTopInset: CGFloat(max(0, ((0..<height).lazy.compactMap { extent($0) }.first?.left ?? lid.left) - lid.left)) / CGFloat(width),
            hinge: CGFloat(hinge) / CGFloat(height),
            deckFront: CGFloat(front) / CGFloat(height),
            deckBottom: CGFloat(bottom + 1) / CGFloat(height),
            edgeTopWidth: CGFloat(extent(edgeTopRow)?.width ?? widest) / CGFloat(width),
            edgeTopRed: Double(top.red) / topCount,
            edgeTopGreen: Double(top.green) / topCount,
            edgeTopBlue: Double(top.blue) / topCount,
            spread: CGFloat(widest) / CGFloat(lid.width),
            red: Double(sum.red) / count,
            green: Double(sum.green) / count,
            blue: Double(sum.blue) / count
        )
    }
}
