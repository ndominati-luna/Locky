import CoreImage.CIFilterBuiltins
import SwiftUI

/// QR code pointing to the iPhone app (replaces the former "Get the link by email").
struct QRCodeView: View {
    let url: URL

    var body: some View {
        if let image = Self.render(url) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .accessibilityLabel(Text("QR code to download Locky on iPhone"))
        }
    }

    private static func render(_ url: URL) -> NSImage? {
        let filter: CIFilter & CIQRCodeGenerator = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }
        let scaled: CIImage = output.transformed(by: CGAffineTransform(scaleX: 8, y: 8))
        let representation: NSCIImageRep = .init(ciImage: scaled)
        let image: NSImage = .init(size: representation.size)
        image.addRepresentation(representation)
        return image
    }
}

/// Where to download the iPhone app.
enum IPhoneAppLink {
    static let download: URL = URL(string: "https://locky.lunabee.studio/ios")!
}
