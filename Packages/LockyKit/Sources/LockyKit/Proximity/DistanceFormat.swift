import Foundation

extension FormatStyle where Self == Measurement<UnitLength>.FormatStyle {
    /// Distances in meters (or feet where appropriate) with one decimal.
    public static var lockyDistance: Self {
        .measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1)))
    }
}
