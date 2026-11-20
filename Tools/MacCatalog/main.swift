import AppKit
import UniformTypeIdentifiers

// Renders every Apple silicon Mac known to this macOS: product image with the screen made
// transparent (the iPhone draws the wallpaper behind it), cropped, PNG; plus a manifest.
let out = URL(fileURLWithPath: CommandLine.arguments[1])
let maxSide = Int(CommandLine.arguments[2]) ?? 1024
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func appleSilicon(_ code: String) -> Bool {
    let base = code.split(separator: "@").first.map(String.init) ?? code
    let letters = base.prefix { $0.isLetter }
    guard let major = Int(base.dropFirst(letters.count).split(separator: ",").first ?? "") else { return false }
    switch letters {
    case "Mac": return major >= 13
    case "MacBookAir": return major >= 10
    case "MacBookPro": return major >= 17
    case "Macmini": return major >= 9
    case "iMac": return major >= 21
    default: return false
    }
}

var declarations: [[String: Any]] = []
let root = URL(fileURLWithPath: "/System/Library/CoreServices/CoreTypes.bundle")
let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)!
for case let url as URL in enumerator where url.lastPathComponent == "Info.plist" {
    guard let dict = NSDictionary(contentsOf: url) as? [String: Any] else { continue }
    declarations += (dict["UTExportedTypeDeclarations"] as? [[String: Any]] ?? []) + (dict["UTImportedTypeDeclarations"] as? [[String: Any]] ?? [])
}

struct Entry: Codable { let id: String; let asset: String; let codes: [String]; let screen: [Double]?; let width: Int; let height: Int; let bytes: Int }
var entries: [Entry] = []
var seen: [String: String] = [:]   // image hash -> asset
for declaration in declarations {
    guard let id = declaration["UTTypeIdentifier"] as? String else { continue }
    let spec = declaration["UTTypeTagSpecification"] as? [String: Any]
    var codes: [String] = []
    if let tags = spec?["com.apple.device-model-code"] as? [String] { codes = tags } else if let tag = spec?["com.apple.device-model-code"] as? String { codes = [tag] }
    guard codes.contains(where: appleSilicon), let type = UTType(id) else { continue }
    var rect = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    guard let icon = NSWorkspace.shared.icon(for: type).cgImage(forProposedRect: &rect, context: nil, hints: nil),
          let bitmap = ScreenLocator.Bitmap(image: icon), let opaque = bitmap.opaqueBounds else { print("skip", id); continue }
    let screen = ScreenLocator.locate(in: bitmap)
    // Punch the screen out (one pixel wider, so no blue fringe shows around the wallpaper).
    var pixels = bitmap.pixels
    if let screen {
        for y in 0..<bitmap.height { for x in 0..<bitmap.width {
            var inside = false
            for dy in -1...1 { for dx in -1...1 {
                let nx = x + dx, ny = y + dy
                if nx >= 0, ny >= 0, nx < bitmap.width, ny < bitmap.height, screen.mask[ny * bitmap.width + nx] > 0 { inside = true }
            } }
            if inside { let i = (y * bitmap.width + x) * 4; pixels[i] = 0; pixels[i+1] = 0; pixels[i+2] = 0; pixels[i+3] = 0 }
        } }
    }
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    let context = CGContext(data: &pixels, width: bitmap.width, height: bitmap.height, bitsPerComponent: 8, bytesPerRow: bitmap.width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let punched = context.makeImage()!.cropping(to: opaque)!
    // Resize to the largest size the iPhone shows.
    let scale = min(1, Double(maxSide) / Double(max(punched.width, punched.height)))
    let w = Int((Double(punched.width) * scale).rounded()), h = Int((Double(punched.height) * scale).rounded())
    let small = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    small.interpolationQuality = .high
    small.draw(punched, in: CGRect(x: 0, y: 0, width: w, height: h))
    let image = small.makeImage()!
    let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!
    let hash = String(png.hashValue)
    let asset: String
    if let existing = seen[png.base64EncodedString().suffix(64).description] { asset = existing } else {
        asset = "Mac-" + id.replacingOccurrences(of: "com.apple.", with: "")
        seen[png.base64EncodedString().suffix(64).description] = asset
        try! png.write(to: out.appending(path: asset + ".png"))
    }
    _ = hash
    let normalized: [Double]? = screen.map { [($0.bounds.minX - opaque.minX) / opaque.width, ($0.bounds.minY - opaque.minY) / opaque.height, $0.bounds.width / opaque.width, $0.bounds.height / opaque.height] }
    entries.append(.init(id: id, asset: asset, codes: codes, screen: normalized, width: w, height: h, bytes: png.count))
}
entries.sort { $0.id < $1.id }
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
try! encoder.encode(entries).write(to: out.appending(path: "manifest.json"))
print("types", entries.count, "images", Set(entries.map(\.asset)).count, "bytes", entries.reduce(0) { $0 + $1.bytes })
