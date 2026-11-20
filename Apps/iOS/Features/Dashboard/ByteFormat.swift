import Foundation

/// Short sizes for the dashboard: "11 GB", "172 GB", "1.2 TB".
enum ByteFormat {
    /// Memory, counted in powers of 1 024 like macOS does ("16 GB" of RAM).
    static func memory(_ bytes: UInt64) -> String {
        format(Double(bytes) / 1_073_741_824)
    }

    /// Disks, counted in powers of 1 000 like the Finder does.
    static func storage(_ bytes: UInt64) -> String {
        format(Double(bytes) / 1_000_000_000)
    }

    private static func format(_ gigabytes: Double) -> String {
        if gigabytes >= 1_000 {
            return Measurement(value: gigabytes / 1_000, unit: UnitInformationStorage.terabytes)
                .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...1))))
        }
        let decimals: ClosedRange<Int> = gigabytes >= 100 ? 0...0 : 0...1
        return Measurement(value: gigabytes, unit: UnitInformationStorage.gigabytes)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(decimals))))
    }
}
