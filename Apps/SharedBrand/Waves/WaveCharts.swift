import Charts
import LockyKit
import SwiftUI

// MARK: - Wi-Fi

/// The Wi-Fi networks of one band as mounds over their channels, the higher the stronger; at
/// 2.4 GHz, the three channels where Bluetooth advertises (and Locky looks for the iPhone) are
/// marked, to see who sits on them.
struct WiFiSpectrumChart: View {
    let networks: [WiFiNetwork]
    let band: WiFiBand

    private struct Point: Identifiable {
        let id: Int
        let network: String
        let frequency: Double
        let level: Double
    }

    /// Networks drawn per band: beyond, the chart is a blur.
    private static let maximumNetworks: Int = 24
    private static let floor: Double = -100
    /// Advertising channels of Bluetooth Low Energy (37, 38, 39), in MHz.
    private static let bluetoothChannels: [Double] = [2402, 2426, 2480]

    var body: some View {
        let shown: [WiFiNetwork] = Array(networks.filter { $0.band == band }.prefix(Self.maximumNetworks))
        Chart {
            if band == .ghz2_4 {
                ForEach(Self.bluetoothChannels, id: \.self) { frequency in
                    RuleMark(x: .value("Frequency", frequency))
                        .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 1.0).opacity(0.7))
                        .lineStyle(.init(lineWidth: 1.5, dash: [4, 3]))
                }
            }
            ForEach(shown) { network in
                let color: Color = Self.color(network, in: shown)
                ForEach(Self.points(network)) { point in
                    AreaMark(
                        x: .value("Frequency", point.frequency),
                        yStart: .value("Floor", Self.floor),
                        yEnd: .value("Signal", point.level),
                        series: .value("Network", point.network)
                    )
                    .foregroundStyle(color.opacity(network.isCurrent ? 0.35 : 0.12))
                    .interpolationMethod(.catmullRom)
                    LineMark(
                        x: .value("Frequency", point.frequency),
                        y: .value("Signal", point.level),
                        series: .value("Network", point.network)
                    )
                    .foregroundStyle(color)
                    .lineStyle(.init(lineWidth: network.isCurrent ? 2.5 : 1.2))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartXScale(domain: band.frequencyRange)
        .chartYScale(domain: Self.floor...(-20))
        .chartXAxis {
            AxisMarks(values: Self.channelMarks(band).map { band.frequency(ofChannel: $0) }) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let frequency = value.as(Double.self), let channel = Self.channelMarks(band).first(where: { band.frequency(ofChannel: $0) == frequency }) {
                        Text(verbatim: "\(channel)")
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [-90, -70, -50, -30]) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let level = value.as(Int.self) {
                        Text(verbatim: "\(level)")
                    }
                }
            }
        }
        .chartLegend(.hidden)
        .frame(height: 190)
        .accessibilityLabel(Text("Wi-Fi networks by channel"))
    }

    private static func points(_ network: WiFiNetwork) -> [Point] {
        let span: ClosedRange<Double> = network.frequencySpan
        let steps: Int = 10
        return (0...steps).map { step in
            let fraction: Double = Double(step) / Double(steps)
            // A rounded mound: full in the middle, nothing at the edges.
            let shape: Double = pow(sin(fraction * .pi), 0.6)
            return .init(
                id: step,
                network: network.id,
                frequency: span.lowerBound + (span.upperBound - span.lowerBound) * fraction,
                level: floor + (Double(network.rssi) - floor) * shape
            )
        }
    }

    static func color(_ network: WiFiNetwork, in networks: [WiFiNetwork]) -> Color {
        if network.isCurrent {
            return Color(red: 0.12, green: 0.55, blue: 1.0)
        }
        let palette: [Color] = [.teal, .purple, .orange, .pink, .mint, .indigo, .brown, .cyan, .yellow]
        let index: Int = networks.firstIndex(of: network) ?? 0
        return palette[index % palette.count]
    }

    static func channelMarks(_ band: WiFiBand) -> [Int] {
        switch band {
        case .ghz2_4: [1, 6, 11, 13]
        case .ghz5: [36, 52, 100, 116, 132, 149, 165]
        case .ghz6: [1, 49, 97, 145, 193]
        }
    }
}

// MARK: - Sound

/// The level of each third of an octave, from the bass on the left to the treble on the right.
struct SoundSpectrumChart: View {
    let spectrum: SoundSpectrum

    /// Frequencies labelled under the bars, each on its closest band.
    private static let labels: [Double] = [50, 200, 1000, 5000, 16_000]

    var body: some View {
        let domain: ClosedRange<Double> = levelDomain
        Chart {
            ForEach(Array(zip(spectrum.frequencies, spectrum.levels).enumerated()), id: \.offset) { item in
                BarMark(
                    x: .value("Band", item.offset),
                    yStart: .value("Floor", domain.lowerBound),
                    yEnd: .value("Level", max(item.element.1, domain.lowerBound))
                )
                .foregroundStyle(
                    LinearGradient(colors: [.purple, .pink, .orange], startPoint: .bottom, endPoint: .top)
                )
                .clipShape(.rect(cornerRadius: 2))
            }
        }
        .chartYScale(domain: domain)
        .chartXAxis {
            AxisMarks(values: labelIndices.map(\.index)) { value in
                AxisValueLabel {
                    if let index = value.as(Int.self), let label = labelIndices.first(where: { $0.index == index }) {
                        Text(verbatim: WaveFormat.hertz(label.frequency))
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 140)
        .accessibilityLabel(Text("Sound spectrum"))
    }

    /// From a little below the quietest band to a little above the loudest one.
    private var levelDomain: ClosedRange<Double> {
        let lowest: Double = spectrum.levels.min() ?? -100
        let highest: Double = spectrum.levels.max() ?? 0
        let floor: Double = max(-120, (lowest - 6).rounded(.down))
        return floor...min(0, max(highest + 6, floor + 20))
    }

    private var labelIndices: [(index: Int, frequency: Double)] {
        Self.labels.compactMap { target in
            spectrum.frequencies.indices
                .min { abs(log(spectrum.frequencies[$0] / target)) < abs(log(spectrum.frequencies[$1] / target)) }
                .map { (index: $0, frequency: target) }
        }
    }
}

// MARK: - Magnetic field

/// The strength of the magnetic field over the measurement, over the band of what the Earth gives.
struct MagneticFieldChart: View {
    let field: MagneticField

    var body: some View {
        Chart {
            RectangleMark(
                xStart: .value("Start", 0),
                xEnd: .value("End", max(field.samples.count - 1, 1)),
                yStart: .value("Earth low", MagneticField.earthRange.lowerBound),
                yEnd: .value("Earth high", MagneticField.earthRange.upperBound)
            )
            .foregroundStyle(.green.opacity(0.12))
            ForEach(Array(field.samples.enumerated()), id: \.offset) { item in
                LineMark(x: .value("Time", item.offset), y: .value("Field", item.element))
                    .foregroundStyle(.mint)
                    .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: 0...max(100, (field.strongest * 1.15).rounded(.up)))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let level = value.as(Double.self) {
                        Text(verbatim: "\(Int(level))")
                    }
                }
            }
        }
        .frame(height: 110)
        .accessibilityLabel(Text("Magnetic field over the measurement"))
    }
}

// MARK: - Link

/// The signal of the iPhone read by the Mac over the measurement, with its average.
struct LinkQualityChart: View {
    let link: LinkQuality

    var body: some View {
        let low: Double = (link.samples.min() ?? -60) - 4
        let high: Double = (link.samples.max() ?? -30) + 4
        Chart {
            RuleMark(y: .value("Average", link.averageRSSI))
                .foregroundStyle(.secondary.opacity(0.6))
                .lineStyle(.init(lineWidth: 1, dash: [3, 3]))
            ForEach(Array(zip(link.times, link.samples).enumerated()), id: \.offset) { item in
                LineMark(x: .value("Time", item.element.0), y: .value("Signal", item.element.1))
                    .foregroundStyle(Color(red: 0.12, green: 0.55, blue: 1.0))
                    .interpolationMethod(.monotone)
            }
        }
        .chartYScale(domain: low...high)
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let level = value.as(Double.self) {
                        Text(verbatim: "\(Int(level))")
                    }
                }
            }
        }
        .frame(height: 110)
        .accessibilityLabel(Text("Signal of your iPhone over the measurement"))
    }
}
