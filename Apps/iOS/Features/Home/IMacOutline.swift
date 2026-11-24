import SwiftUI
import UIKit

/// Where the parts of an iMac are in its picture from the catalog, measured once from the picture
/// itself: every iMac of macOS is drawn the same way, face on, its display and its chin above a
/// foot much narrower. The display turns on the hinge at the top of the foot; the foot stays. The
/// colour of the chin is the colour of the keyboard and the trackpad that come with it. Fractions
/// of the picture.
struct IMacOutline: Equatable {
    /// The bottom of the chin, where the foot shows under it.
    let chinBottom: CGFloat
    /// The desk, under the sole of the foot.
    let desk: CGFloat
    /// The colour of the chin, in sRGB.
    let red: Double
    let green: Double
    let blue: Double

    var aluminium: Color {
        Color(.sRGB, red: red, green: green, blue: blue)
    }

    /// Measured once per picture.
    @MainActor private static var cache: [String: IMacOutline?] = [:]

    /// The outline of an iMac of the catalog, `nil` for another Mac or a picture it cannot read.
    @MainActor
    static func of(_ frame: MacFrame) -> IMacOutline? {
        guard let asset = frame.asset, frame.screen != nil else { return nil }
        if let outline = cache[asset] {
            return outline
        }
        let outline: IMacOutline? = measure(frame.image)
        cache[asset] = outline
        return outline
    }

    /// Reads the outline from the transparency of the picture: the rows of the display are all as
    /// wide, the first much narrower one is the foot, the last opaque one its sole on the desk.
    private static func measure(_ image: UIImage) -> IMacOutline? {
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
        /// The width of the opaque part of a row.
        func extent(_ y: Int) -> Int? {
            guard
                let left = (0..<width).first(where: { alpha($0, y) > 128 }),
                let right = (0..<width).last(where: { alpha($0, y) > 128 })
            else { return nil }
            return right - left + 1
        }

        // The edges of the screen, at a third of the height: the display.
        guard let display = extent(height / 3), display > width * 9 / 10 else { return nil }
        guard
            let foot = ((height / 2)..<height).first(where: { (extent($0) ?? 0) < display * 6 / 10 }),
            let sole = ((height / 2)..<height).last(where: { extent($0) != nil }),
            Double(foot) > Double(height) * 0.6, sole > foot + height / 20
        else { return nil }

        // The chin, clear of the screen above it and of the shadow of its edge.
        let chinRows: Range<Int> = (foot - height * 6 / 100)..<(foot - height * 3 / 100)
        var sum: (red: Int, green: Int, blue: Int, count: Int) = (0, 0, 0, 0)
        for y in chinRows {
            for x in Array(width * 10 / 100..<width * 30 / 100) + Array(width * 70 / 100..<width * 90 / 100) {
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
            chinBottom: CGFloat(foot) / CGFloat(height),
            desk: CGFloat(sole + 1) / CGFloat(height),
            red: Double(sum.red) / count,
            green: Double(sum.green) / count,
            blue: Double(sum.blue) / count
        )
    }
}
