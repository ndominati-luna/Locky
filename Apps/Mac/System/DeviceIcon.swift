import AppKit
import UniformTypeIdentifiers

/// Exact product images of Apple devices, provided by macOS itself (CoreTypes).
///
/// This replaces the hand made illustrations of the former app, which only knew a handful of
/// models: macOS knows every Mac and iPhone it supports, with the right shape and color.
enum DeviceIcon {
    private static var modelCodeTagClass: UTTagClass {
        .init(rawValue: "com.apple.device-model-code")
    }

    /// Image of this Mac, as displayed in "About This Mac".
    static var thisMac: NSImage {
        NSImage(named: NSImage.computerName) ?? NSWorkspace.shared.icon(for: .application)
    }

    /// Exact type of this Mac for macOS, model and color ("com.apple.macbookpro-14-2021-space-gray"):
    /// the iPhone picks its image in ``MacCatalog`` with it. macOS draws this Mac in its color but
    /// does not tell which one: the color variant of the model whose image matches it is picked.
    static let thisMacType: String? = {
        let model: String = MacDeviceInfo.modelIdentifier
        var candidates: [UTType] = []
        if let base = UTType(tag: model, tagClass: modelCodeTagClass, conformingTo: nil), !base.isDynamic {
            candidates.append(base)
        }
        for color in 1...16 {
            if let variant = UTType(tag: "\(model)@ECOLOR=\(color)", tagClass: modelCodeTagClass, conformingTo: nil),
               !variant.isDynamic, !candidates.contains(variant) {
                candidates.append(variant)
            }
        }
        guard candidates.count > 1, let reference = thumbnail(thisMac) else { return candidates.first?.identifier }
        return candidates.min { lhs, rhs in
            difference(reference, thumbnail(NSWorkspace.shared.icon(for: lhs)))
                < difference(reference, thumbnail(NSWorkspace.shared.icon(for: rhs)))
        }?.identifier
    }()

    /// 32 × 32 RGBA pixels, enough to tell the colors apart.
    private static func thumbnail(_ image: NSImage) -> [UInt8]? {
        var rect: NSRect = .init(x: 0, y: 0, width: 256, height: 256)
        guard
            let cgImage = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
            let space = CGColorSpace(name: CGColorSpace.sRGB)
        else { return nil }
        var pixels: [UInt8] = .init(repeating: 0, count: 32 * 32 * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: 32,
                height: 32,
                bitsPerComponent: 8,
                bytesPerRow: 32 * 4,
                space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .high
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 32, height: 32))
            return true
        }
        return drawn ? pixels : nil
    }

    private static func difference(_ lhs: [UInt8], _ rhs: [UInt8]?) -> Int {
        guard let rhs, rhs.count == lhs.count else { return .max }
        return zip(lhs, rhs).reduce(0) { $0 + abs(Int($1.0) - Int($1.1)) }
    }

    /// Image of a device from its model identifier ("iPhone18,1"), `nil` when macOS does not know it.
    static func image(forModelIdentifier identifier: String) -> NSImage? {
        guard
            let type = UTType(tag: identifier, tagClass: modelCodeTagClass, conformingTo: nil),
            !type.isDynamic
        else { return nil }
        return NSWorkspace.shared.icon(for: type)
    }
}
