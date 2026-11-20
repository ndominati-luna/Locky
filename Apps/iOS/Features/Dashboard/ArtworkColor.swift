import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// Average color of an artwork, to tint the glass of the music card with it.
enum ArtworkColor {
    @concurrent
    static func average(of data: Data) async -> Color? {
        guard let image = CIImage(data: data) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = image
        filter.extent = image.extent
        guard let output = filter.outputImage else { return nil }
        var pixel: [UInt8] = [0, 0, 0, 0]
        let context: CIContext = .init(options: [.workingColorSpace: NSNull()])
        context.render(output, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return Color(red: Double(pixel[0]) / 255, green: Double(pixel[1]) / 255, blue: Double(pixel[2]) / 255)
    }
}
