import CoreGraphics
import Foundation

/// Finds the display inside a CoreTypes product image.
///
/// Two strategies:
/// 1. MacBook icons draw their screen as a saturated sky blue gradient: those pixels are the screen,
///    notch and rounded corners included.
/// 2. Other icons (iMac 24" for instance, light grey panel): region growing from the expected center
///    of the screen, accepted only if the region is a well filled 16:10–16:9 rectangle.
/// Macs without a display (mini, Studio, Pro) yield `nil`.
struct ScreenLocator {
    /// Screen pixels (255) in a grayscale buffer, top-down rows.
    let mask: [UInt8]
    /// Screen bounds in pixels, top-down coordinates.
    let bounds: CGRect

    /// RGBA, premultiplied, top-down rows.
    struct Bitmap {
        let pixels: [UInt8]
        let width: Int
        let height: Int

        init?(image: CGImage) {
            width = image.width
            height = image.height
            var buffer: [UInt8] = .init(repeating: 0, count: width * height * 4)
            guard let context = CGContext(
                data: &buffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            pixels = buffer
        }

        func alpha(_ x: Int, _ y: Int) -> UInt8 {
            pixels[(y * width + x) * 4 + 3]
        }

        func rgb(_ x: Int, _ y: Int) -> (Int, Int, Int) {
            let index: Int = (y * width + x) * 4
            return (Int(pixels[index]), Int(pixels[index + 1]), Int(pixels[index + 2]))
        }

        /// Bounds of the non transparent pixels, top-down coordinates.
        var opaqueBounds: CGRect? {
            var minX: Int = width
            var minY: Int = height
            var maxX: Int = -1
            var maxY: Int = -1
            for y in 0..<height {
                for x in 0..<width where alpha(x, y) > 8 {
                    minX = min(minX, x)
                    maxX = max(maxX, x)
                    minY = min(minY, y)
                    maxY = max(maxY, y)
                }
            }
            guard maxX >= minX, maxY >= minY else { return nil }
            return .init(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
    }

    static func locate(in bitmap: Bitmap) -> ScreenLocator? {
        blueScreen(in: bitmap) ?? grownScreen(in: bitmap)
    }

    // MARK: - Blue screens (MacBooks, Intel iMacs)

    private static func blueScreen(in bitmap: Bitmap) -> ScreenLocator? {
        var mask: [UInt8] = .init(repeating: 0, count: bitmap.width * bitmap.height)
        var bounds: Bounds = .init()
        for y in 0..<bitmap.height {
            for x in 0..<bitmap.width where bitmap.alpha(x, y) > 200 {
                let (red, green, blue): (Int, Int, Int) = bitmap.rgb(x, y)
                guard blue > 150, blue - red > 60, green > red else { continue }
                mask[y * bitmap.width + x] = 255
                bounds.add(x, y)
            }
        }
        guard bounds.count > bitmap.width * bitmap.height / 20, let rect = bounds.rect else { return nil }
        return .init(mask: mask, bounds: rect)
    }

    // MARK: - Other screens

    private static func grownScreen(in bitmap: Bitmap) -> ScreenLocator? {
        guard let opaque = bitmap.opaqueBounds else { return nil }
        let seedX: Int = .init(opaque.midX)
        // The display fills the upper part of the device: start a third of the way down.
        let seedY: Int = .init(opaque.minY + opaque.height * 0.33)
        guard bitmap.alpha(seedX, seedY) > 200 else { return nil }
        let seed: (Int, Int, Int) = bitmap.rgb(seedX, seedY)

        var mask: [UInt8] = .init(repeating: 0, count: bitmap.width * bitmap.height)
        var bounds: Bounds = .init()
        var stack: [(Int, Int)] = [(seedX, seedY)]
        mask[seedY * bitmap.width + seedX] = 255
        while let (x, y) = stack.popLast() {
            bounds.add(x, y)
            let current: (Int, Int, Int) = bitmap.rgb(x, y)
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                guard nx >= 0, ny >= 0, nx < bitmap.width, ny < bitmap.height else { continue }
                let index: Int = ny * bitmap.width + nx
                guard mask[index] == 0, bitmap.alpha(nx, ny) > 200 else { continue }
                let color: (Int, Int, Int) = bitmap.rgb(nx, ny)
                // Smooth gradients are followed step by step, but never far from the seed color.
                guard distance(color, current) <= 6, distance(color, seed) <= 40 else { continue }
                mask[index] = 255
                stack.append((nx, ny))
            }
        }
        guard let rect = bounds.rect else { return nil }
        let fill: Double = Double(bounds.count) / Double(rect.width * rect.height)
        let ratio: Double = rect.width / rect.height
        let coverage: Double = rect.width * rect.height / (opaque.width * opaque.height)
        guard fill > 0.9, (1.2...1.95).contains(ratio), coverage > 0.15 else { return nil }
        return .init(mask: mask, bounds: rect)
    }

    private static func distance(_ lhs: (Int, Int, Int), _ rhs: (Int, Int, Int)) -> Int {
        max(abs(lhs.0 - rhs.0), abs(lhs.1 - rhs.1), abs(lhs.2 - rhs.2))
    }

    private struct Bounds {
        var minX: Int = .max
        var minY: Int = .max
        var maxX: Int = .min
        var maxY: Int = .min
        var count: Int = 0

        mutating func add(_ x: Int, _ y: Int) {
            minX = min(minX, x)
            maxX = max(maxX, x)
            minY = min(minY, y)
            maxY = max(maxY, y)
            count += 1
        }

        var rect: CGRect? {
            guard count > 0 else { return nil }
            return .init(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
        }
    }
}
