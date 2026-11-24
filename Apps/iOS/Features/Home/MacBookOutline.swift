import SwiftUI
import UIKit

/// Where the parts of a MacBook are in its picture from the catalog, measured once from the
/// picture itself: every MacBook of macOS is drawn the same way, from the front and a little from
/// above. The lid is a rectangle down to its hinge; under it, the deck widens toward its front edge
/// (the perspective of the picture); the aluminium shows on that edge. Fractions of the picture.
struct MacBookOutline: Equatable {
    /// The sides of the lid.
    let lidLeft: CGFloat
    let lidRight: CGFloat
    /// The bottom of the lid, where it turns on the deck.
    let hinge: CGFloat
    /// The front edge of the deck, where the picture is widest.
    let deckFront: CGFloat
    /// How much wider the front of the deck looks than the lid.
    let spread: CGFloat
    /// The colour of the aluminium, in sRGB.
    let red: Double
    let green: Double
    let blue: Double

    var aluminium: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// Measured once per picture.
    @MainActor private static var cache: [String: MacBookOutline?] = [:]

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

        return .init(
            lidLeft: CGFloat(lid.left) / CGFloat(width),
            lidRight: CGFloat(lid.left + lid.width) / CGFloat(width),
            hinge: CGFloat(hinge) / CGFloat(height),
            deckFront: CGFloat(front) / CGFloat(height),
            spread: CGFloat(widest) / CGFloat(lid.width),
            red: Double(sum.red) / count,
            green: Double(sum.green) / count,
            blue: Double(sum.blue) / count
        )
    }
}
