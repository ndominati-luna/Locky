import LockyKit
import SwiftUI

/// The details a card of a measurement opens in a sheet.
enum WaveDetailKind: String, Identifiable {
    case impact
    case bluetooth
    case wifi
    case link
    case sound
    case magneticField

    var id: String {
        rawValue
    }
}

/// A measurement of the waves: what it means for Locky first, then each wave measured, each card
/// opening its details in a sheet. The cards fill as many columns as the width allows (one on an
/// iPhone, two or three on the open iPhone Duo or a wide Mac window).
struct WaveScanDetailView: View {
    let scan: WaveScan
    /// Shows a button to delete the measurement next to its name.
    var delete: (() -> Void)?
    @State private var detail: WaveDetailKind?
    @State private var band: WiFiBand = .ghz2_4
    @State private var width: CGFloat = 0

    /// The cards of a measurement, in the order they are read.
    private enum Card: Hashable {
        case impact
        case bluetooth
        case wifi
        case link
        case sound
        case magneticField
        case networks

        /// Rough height, to balance the columns.
        var estimatedHeight: CGFloat {
            switch self {
            case .impact: 430
            case .bluetooth: 560
            case .wifi: 420
            case .link: 260
            case .sound: 320
            case .magneticField: 290
            case .networks: 130
            }
        }
    }

    private static let minimumColumnWidth: CGFloat = 300
    private static let spacing: CGFloat = 16
    private static let padding: CGFloat = 16

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.spacing) {
                header
                missingParts
                HStack(alignment: .top, spacing: Self.spacing) {
                    ForEach(Array(columns.enumerated()), id: \.offset) { column in
                        VStack(spacing: Self.spacing) {
                            ForEach(column.element, id: \.self) { card in
                                view(for: card)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }
                }
                Text(WaveFactorText.harmless)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            .padding(Self.padding)
            .frame(maxWidth: columnCount == 1 ? 720 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
        .sheet(item: $detail) { kind in
            WaveDetailSheet(kind: kind, scan: scan)
        }
        .onAppear {
            band = Self.initialBand(scan.mac)
        }
    }

    // MARK: - Layout

    private var columnCount: Int {
        let available: CGFloat = width - Self.padding * 2
        return max(1, min(3, Int((available + Self.spacing) / (Self.minimumColumnWidth + Self.spacing))))
    }

    private var cards: [Card] {
        var cards: [Card] = [.impact]
        if scan.mac != nil || scan.phone != nil {
            cards.append(.bluetooth)
        }
        if let mac = scan.mac {
            cards.append(.wifi)
            if mac.link != nil {
                cards.append(.link)
            }
        }
        if scan.phone?.sound != nil {
            cards.append(.sound)
        }
        if scan.phone?.magneticField != nil {
            cards.append(.magneticField)
        }
        if scan.mac?.wifiConnection != nil || scan.phone?.cellular != nil {
            cards.append(.networks)
        }
        return cards
    }

    /// The cards in reading order, each in the shortest column so far.
    private var columns: [[Card]] {
        var columns: [[Card]] = .init(repeating: [], count: columnCount)
        var heights: [CGFloat] = .init(repeating: 0, count: columnCount)
        for card in cards {
            let shortest: Int = heights.indices.min { heights[$0] < heights[$1] } ?? 0
            columns[shortest].append(card)
            heights[shortest] += card.estimatedHeight
        }
        return columns
    }

    @ViewBuilder
    private func view(for card: Card) -> some View {
        switch card {
        case .impact:
            WaveImpactCard(scan: scan) { detail = .impact }
        case .bluetooth:
            bluetoothCard
        case .wifi:
            if let mac = scan.mac {
                wifiCard(mac)
            }
        case .link:
            if let link = scan.mac?.link {
                linkCard(link)
            }
        case .sound:
            if let sound = scan.phone?.sound {
                soundCard(sound)
            }
        case .magneticField:
            if let field = scan.phone?.magneticField {
                magneticCard(field)
            }
        case .networks:
            networksCard
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: scan.name.isEmpty ? String(localized: "Measurement") : scan.name)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .lineLimit(2)
                Text(scan.date, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let delete {
                Button("Delete", systemImage: "trash", role: .destructive, action: delete)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .controlSize(.large)
            }
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var missingParts: some View {
        if scan.mac == nil || scan.phone == nil {
            VStack(alignment: .leading, spacing: 6) {
                if scan.mac == nil {
                    Label("Your Mac’s part is missing: no Wi-Fi, nor the link with your iPhone.", systemImage: "laptopcomputer.slash")
                }
                if scan.phone == nil {
                    Label("Your iPhone’s part is missing: no sound, nor magnetic field.", systemImage: "iphone.slash")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }

    @ViewBuilder
    private var bluetoothCard: some View {
        let mac: [BluetoothNeighbor] = scan.mac?.bluetoothDevices ?? []
        let phone: [BluetoothNeighbor] = scan.phone?.bluetoothDevices ?? []
        if scan.mac != nil || scan.phone != nil {
            let crowd: BluetoothCrowd = .init(scan: scan)
            WaveCard(title: "Bluetooth around", systemImage: "dot.radiowaves.left.and.right", showDetails: { detail = .bluetooth }) {
                BluetoothRadarView(mac: mac, phone: phone)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    BluetoothRadarLegend()
                }
                .frame(maxWidth: .infinity)
                HStack(alignment: .top) {
                    WaveMetric(value: "\(crowd.total)", label: "devices heard")
                    WaveMetric(value: "\(crowd.nearby)", label: "close by")
                    if let classic = scan.mac?.classicDevices {
                        WaveMetric(value: "\(classic.count { !$0.isPaired || $0.rssi != nil })", label: "classic Bluetooth")
                    }
                }
            }
        }
    }

    private func wifiCard(_ mac: MacWaveCapture) -> some View {
        let bands: [WiFiBand] = WiFiBand.allCases.filter { band in mac.wifiNetworks.contains { $0.band == band } }
        return WaveCard(title: "Wi-Fi", systemImage: "wifi", showDetails: { detail = .wifi }) {
            if mac.wifiNetworks.isEmpty {
                Text("No Wi-Fi network heard: the Wi-Fi of your Mac may be off.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                if bands.count > 1 {
                    Picker("Band", selection: $band) {
                        ForEach(bands, id: \.self) { band in
                            Text(verbatim: WaveFormat.band(band)).tag(band)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                WiFiSpectrumChart(networks: mac.wifiNetworks, band: bands.contains(band) ? band : bands.first ?? .ghz2_4)
                if band == .ghz2_4 {
                    Label("Dotted lines: where Bluetooth advertises, and Locky looks for your iPhone.", systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .top) {
                    WaveMetric(value: "\(mac.wifiNetworks.count)", label: "networks heard")
                    WaveMetric(value: "\(mac.wifiNetworks.count { $0.band == .ghz2_4 })", label: "at 2.4 GHz")
                    if let connection = mac.wifiConnection {
                        WaveMetric(value: WaveFormat.band(connection.band), label: "your Mac", tint: connection.band == .ghz2_4 ? .orange : .primary)
                    }
                }
                if mac.areNetworkNamesHidden {
                    Label("macOS hides the names of the networks: allow Locky in Location Services to see them.", systemImage: "location.slash")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func linkCard(_ link: LinkQuality) -> some View {
        WaveCard(title: "Link with your iPhone", systemImage: "link", showDetails: { detail = .link }) {
            LinkQualityChart(link: link)
            HStack(alignment: .top) {
                WaveMetric(value: WaveFormat.dBm(link.averageRSSI), label: "average signal")
                WaveMetric(value: WaveFormat.deviation(link.deviation), label: "steadiness")
                WaveMetric(value: "\(link.dropouts)", label: "dropouts", tint: link.dropouts > 0 ? .orange : .primary)
            }
        }
    }

    private func soundCard(_ sound: SoundSpectrum) -> some View {
        WaveCard(title: "Sound", systemImage: "waveform", showDetails: { detail = .sound }) {
            SoundSpectrumChart(spectrum: sound)
            HStack(alignment: .top) {
                WaveMetric(value: WaveFormat.decibels(sound.averageLevel), label: "average level")
                WaveMetric(value: WaveFormat.decibels(sound.peakLevel), label: "loudest")
                if let dominant = sound.dominantFrequency {
                    WaveMetric(value: WaveFormat.hertz(dominant), label: "dominant pitch")
                }
            }
        }
    }

    private func magneticCard(_ field: MagneticField) -> some View {
        WaveCard(title: "Magnetic field", systemImage: "location.north.line", showDetails: { detail = .magneticField }) {
            MagneticFieldChart(field: field)
            HStack(alignment: .top) {
                WaveMetric(value: WaveFormat.microteslas(field.average), label: "average")
                WaveMetric(value: WaveFormat.microteslas(field.strongest), label: "strongest")
                WaveMetric(value: WaveFormat.microteslas(MagneticField.earthRange.upperBound), label: "the Earth, at most")
            }
        }
    }

    @ViewBuilder
    private var networksCard: some View {
        let connection: WiFiConnection? = scan.mac?.wifiConnection
        let cellular: CellularTechnology? = scan.phone?.cellular
        if connection != nil || cellular != nil {
            WaveCard(title: "Networks in use", systemImage: "network") {
                if let connection {
                    LabeledContent {
                        Text(verbatim: "\(WaveFormat.band(connection.band)) · \(String(localized: "channel \(connection.channel)")) · \(WaveFormat.rate(connection.transmitRate))")
                    } label: {
                        Label {
                            Text(verbatim: connection.ssid ?? String(localized: "Wi-Fi of your Mac"))
                        } icon: {
                            Image(systemName: "wifi")
                        }
                    }
                }
                if let cellular {
                    LabeledContent {
                        Text(verbatim: cellular.name)
                    } label: {
                        Label("Mobile network of your iPhone", systemImage: "antenna.radiowaves.left.and.right")
                    }
                }
            }
            .font(.subheadline)
        }
    }

    private static func initialBand(_ mac: MacWaveCapture?) -> WiFiBand {
        guard let mac else { return .ghz2_4 }
        if mac.wifiNetworks.contains(where: { $0.band == .ghz2_4 }) {
            return .ghz2_4
        }
        return mac.wifiConnection?.band ?? mac.wifiNetworks.first?.band ?? .ghz2_4
    }
}
