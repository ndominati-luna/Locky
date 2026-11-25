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
    /// The colour of the front edge of the shut lid (see ``lidEdge(of:outline:)``) under its top,
    /// which the back of the lid carries on from.
    let edgeTopRed: Double
    let edgeTopGreen: Double
    let edgeTopBlue: Double
    /// The same toward its ends, darker as the light falls off: the colour of its rounded ends.
    let edgeEndRed: Double
    let edgeEndGreen: Double
    let edgeEndBlue: Double
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

    var edgeEnd: Color {
        Color(.sRGB, red: edgeEndRed, green: edgeEndGreen, blue: edgeEndBlue)
    }

    /// Measured once per picture.
    @MainActor private static var cache: [String: MacBookOutline?] = [:]
    @MainActor private static var edges: [String: UIImage?] = [:]
    /// How thick the lid is next to the deck, as a fraction of the face of the deck (4.5 mm over
    /// 10 mm on a MacBook Pro): its front edge is the top of that face, as tall.
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
    /// same aluminium in the same light: the top of the face of the deck, its bright top edge and
    /// its brushed face, as the light from above falls on both faces alike, the notch of the deck
    /// filled with the face on either side of it. (The lower part of the face, where it turns
    /// toward the desk, is in its shadow: on the lid it made a dark band the deck does not have.)
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
        let top: Int = Int((outline.deckFront * height).rounded())
        let bottom: Int = Int(((outline.deckFront + (outline.deckBottom - outline.deckFront) * edgeThickness) * height).rounded())
        guard bottom > top, let slice = cgImage.cropping(to: CGRect(x: 0, y: top, width: cgImage.width, height: bottom - top)) else {
            return nil
        }
        let width: Int = slice.width
        let rows: Int = slice.height
        var pixels: [UInt8] = .init(repeating: 0, count: width * rows * 4)
        let edge: CGImage? = pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: width,
                height: rows,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.draw(slice, in: CGRect(x: 0, y: 0, width: width, height: rows))
            for row in 0..<rows {
                fillNotch(in: buffer, row: row, width: width)
            }
            return context.makeImage()
        }
        return edge.map { UIImage(cgImage: $0) }
    }

    /// The notch in the middle of the face of the deck, on one row of it: brighter or darker than
    /// the face around, which the light shades evenly from its middle to its ends. Filled with the
    /// face on either side of it, mirrored, its grain and its light carrying on.
    private static func fillNotch(in buffer: UnsafeMutableRawBufferPointer, row: Int, width: Int) {
        guard let base = buffer.baseAddress else { return }
        let bytes: UnsafeMutablePointer<UInt8> = base.assumingMemoryBound(to: UInt8.self)
        func brightness(_ x: Int) -> Double {
            let index: Int = (row * width + x) * 4
            return (Double(bytes[index]) + Double(bytes[index + 1]) + Double(bytes[index + 2])) / 3
        }
        /// Around a column, clear of the grain.
        func around(_ x: Int) -> Double {
            (max(0, x - 2)...min(width - 1, x + 2)).map(brightness).reduce(0, +) / 5
        }
        let start: Int = width * 35 / 100
        let end: Int = width * 65 / 100
        guard end - start > 10 else { return }
        let left: Double = around(start)
        let right: Double = around(end)
        let odd: [Int] = (start...end).filter { x in
            let even: Double = left + (right - left) * Double(x - start) / Double(end - start)
            return abs(brightness(x) - even) > 12
        }
        guard odd.count > 3, let first = odd.first, let last = odd.last else { return }
        let from: Int = max(width * 30 / 100, first - 2)
        let to: Int = min(width * 70 / 100, last + 2)
        let middle: Int = (from + to) / 2
        for x in from...to {
            let source: Int = x <= middle ? from - 1 - (x - from) : to + 1 + (to - x)
            let target: Int = (row * width + x) * 4
            let origin: Int = (row * width + source) * 4
            for channel in 0..<4 {
                bytes[target + channel] = bytes[origin + channel]
            }
        }
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

        // The colour of the edge of the lid, the top of the face of the deck: its brushed face under
        // its bright top edge, clear of the notch in its middle; and close to its rounded ends.
        let faceTop: Int = front + (bottom + 1 - front) / 8
        let faceRows: ClosedRange<Int> = faceTop...max(faceTop, front + (bottom + 1 - front) / 4)
        func average(_ columns: [Int]) -> (red: Double, green: Double, blue: Double)? {
            var total: (red: Int, green: Int, blue: Int, count: Int) = (0, 0, 0, 0)
            for y in faceRows {
                for x in columns {
                    let index: Int = (y * width + x) * 4
                    guard pixels[index + 3] > 250 else { continue }
                    total.red += Int(pixels[index])
                    total.green += Int(pixels[index + 1])
                    total.blue += Int(pixels[index + 2])
                    total.count += 1
                }
            }
            guard total.count > 0 else { return nil }
            let scale: Double = Double(total.count) * 255
            return (Double(total.red) / scale, Double(total.green) / scale, Double(total.blue) / scale)
        }
        guard
            let top = average(Array(width * 20 / 100..<width * 35 / 100) + Array(width * 65 / 100..<width * 80 / 100)),
            let ends = average(Array(width * 3 / 100..<width * 7 / 100) + Array(width * 93 / 100..<width * 97 / 100))
        else { return nil }

        return .init(
            lidLeft: CGFloat(lid.left) / CGFloat(width),
            lidRight: CGFloat(lid.left + lid.width) / CGFloat(width),
            lidTopInset: CGFloat(max(0, ((0..<height).lazy.compactMap { extent($0) }.first?.left ?? lid.left) - lid.left)) / CGFloat(width),
            hinge: CGFloat(hinge) / CGFloat(height),
            deckFront: CGFloat(front) / CGFloat(height),
            deckBottom: CGFloat(bottom + 1) / CGFloat(height),
            edgeTopRed: top.red,
            edgeTopGreen: top.green,
            edgeTopBlue: top.blue,
            edgeEndRed: ends.red,
            edgeEndGreen: ends.green,
            edgeEndBlue: ends.blue,
            spread: CGFloat(widest) / CGFloat(lid.width),
            red: Double(sum.red) / count,
            green: Double(sum.green) / count,
            blue: Double(sum.blue) / count
        )
    }
}
