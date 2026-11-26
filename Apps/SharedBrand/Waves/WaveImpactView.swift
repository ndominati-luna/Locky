import LockyKit
import SwiftUI

/// What the waves of a measurement mean for Locky: a gauge, a verdict, and each thing judged.
struct WaveImpactCard: View {
    let scan: WaveScan
    var showDetails: (() -> Void)?

    var body: some View {
        let impact: WaveImpact = scan.impact
        WaveCard(title: "Impact on Locky", systemImage: "gauge.with.dots.needle.50percent", showDetails: showDetails) {
            if impact.factors.isEmpty {
                Text("Nothing to judge: your Mac did not take part in this measurement.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(alignment: .center, spacing: 16) {
                    ImpactGauge(score: impact.score, level: impact.level)
                        .frame(width: 92, height: 92)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(impact.level.title)
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .foregroundStyle(impact.level.color)
                        Text(impact.level.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                VStack(spacing: 10) {
                    ForEach(impact.factors) { factor in
                        WaveFactorRow(factor: factor, scan: scan)
                    }
                }
            }
        }
    }
}

/// A ring filled from calm to crowded, in the colors of the levels.
struct ImpactGauge: View {
    let score: Double
    let level: WaveImpact.Level
    /// Small, in a row of a list.
    var isCompact: Bool = false

    private var lineWidth: CGFloat {
        isCompact ? 5 : 10
    }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 0.75)
                .stroke(Color.secondary.opacity(0.2), style: .init(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle()
                .trim(from: 0, to: 0.75 * max(0.04, min(score, 1)))
                .stroke(
                    AngularGradient(colors: [.green, .yellow, .orange, .red], center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                    style: .init(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(135))
            Image(systemName: level.systemImage)
                .font(.system(size: isCompact ? 15 : 26, weight: .semibold))
                .foregroundStyle(level.color)
                .contentTransition(.symbolEffect(.replace))
        }
        .padding(lineWidth / 2)
        .animation(.smooth(duration: 0.8), value: score)
        .accessibilityElement()
        .accessibilityLabel(Text(level.title))
    }
}

/// One thing judged: its name, what was measured, its level.
struct WaveFactorRow: View {
    let factor: WaveImpact.Factor
    let scan: WaveScan
    var isDetailed: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: factor.kind.systemImage)
                .font(.callout.weight(.semibold))
                .foregroundStyle(factor.level.color)
                .frame(width: 30, height: 30)
                .background(factor.level.color.opacity(0.15), in: .circle)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(factor.kind.title)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    Text(factor.level.title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(factor.level.color)
                }
                Text(verbatim: WaveFactorText.value(factor.kind, scan: scan))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if isDetailed {
                    Text(WaveFactorText.explanation(factor, scan: scan))
                        .font(.footnote)
                        .padding(.top, 2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// What was measured for each thing judged, and what it means.
enum WaveFactorText {
    static func value(_ kind: WaveImpact.Kind, scan: WaveScan) -> String {
        switch kind {
        case .link:
            guard let link = scan.mac?.link else { return "" }
            return String(localized: "Signal \(WaveFormat.dBm(link.averageRSSI)), steady within \(WaveFormat.deviation(link.deviation))")
        case .bluetooth:
            let crowd: BluetoothCrowd = .init(scan: scan)
            return String(localized: "Devices heard: \(crowd.total), close by: \(crowd.nearby)")
        case .wifi:
            let strong: Int = scan.mac?.wifiNetworks.count { $0.band == .ghz2_4 && $0.rssi >= WaveImpact.strongWiFiRSSI } ?? 0
            let band: String = scan.mac?.wifiConnection.map { WaveFormat.band($0.band) } ?? String(localized: "no Wi-Fi")
            return String(localized: "Strong 2.4 GHz networks: \(strong), your Mac: \(band)")
        case .macBluetooth:
            let connected: [ClassicBluetoothDevice] = scan.mac?.classicDevices.filter(\.isConnected) ?? []
            let audio: Int = connected.count { $0.kind == .audio }
            return String(localized: "Connected: \(connected.count), of which audio: \(audio)")
        }
    }

    static func explanation(_ factor: WaveImpact.Factor, scan: WaveScan) -> LocalizedStringKey {
        switch (factor.kind, factor.level) {
        case (.link, .calm):
            return "Lying next to your Mac, your iPhone kept a steady signal: the distance Locky measures will be precise here."
        case (.link, .busy):
            return "Lying still, your iPhone still saw its signal move a little: the distance may waver by a few tens of centimeters."
        case (.link, .crowded):
            return "Lying still, your iPhone saw its signal jump around: Locky may lock or unlock late. Keep your iPhone uncovered, and away from metal."
        case (.bluetooth, .calm):
            return "Few Bluetooth devices around: they leave the channels of Locky free."
        case (.bluetooth, .busy):
            return "Quite a few Bluetooth devices around. They advertise on the same channels as Locky, which can live with it."
        case (.bluetooth, .crowded):
            return "Many Bluetooth devices, some very close: they crowd the channels of Locky, and some readings of the distance get lost."
        case (.wifi, _) where scan.mac?.wifiConnection?.band == .ghz2_4:
            return "Your Mac uses Wi-Fi at 2.4 GHz: its Wi-Fi and its Bluetooth take turns on the same antenna. Connect it at 5 GHz if your box offers it: Locky will hear your iPhone better."
        case (.wifi, .calm):
            return "Bluetooth shares the 2.4 GHz band with Wi-Fi. Few strong networks there, and your Mac stays away from it."
        case (.wifi, _):
            return "Bluetooth shares the 2.4 GHz band with Wi-Fi, and many strong networks use it here: Bluetooth has to dodge them."
        case (.macBluetooth, .calm):
            return "Nothing that streams sound is connected to your Mac: its Bluetooth radio is all Locky's."
        case (.macBluetooth, _):
            return "Headphones or speakers stream sound over the Bluetooth of your Mac: Locky shares its radio with them."
        }
    }

    /// Sound and the magnetic field: shown, never judged.
    static var harmless: LocalizedStringKey {
        "Sound and the magnetic field do nothing to Bluetooth: they are only shown."
    }
}
