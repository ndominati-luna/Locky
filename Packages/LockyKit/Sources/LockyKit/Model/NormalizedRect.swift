import CoreGraphics
import Foundation

/// A rectangle expressed in fractions of an image (origin at the top left corner).
///
/// Used to locate the screen inside the product image of the Mac, so the iPhone can draw the
/// lock screen (avatar and password field) exactly in the middle of it, whatever the model.
public struct NormalizedRect: Codable, Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The rectangle in a container of the given size.
    public func rect(in size: CGSize) -> CGRect {
        .init(x: x * size.width, y: y * size.height, width: width * size.width, height: height * size.height)
    }

    /// Compact textual form, for CloudKit and WatchConnectivity metadata.
    public var stringValue: String {
        [x, y, width, height].map { String($0) }.joined(separator: ",")
    }

    public init?(stringValue: String) {
        let values: [Double] = stringValue.split(separator: ",").compactMap { Double($0) }
        guard values.count == 4 else { return nil }
        self.init(x: values[0], y: values[1], width: values[2], height: values[3])
    }
}
