import LockyKit
import SwiftUI

/// Everything measured for one card of a measurement.
struct WaveDetailSheet: View {
    let kind: WaveDetailKind
    let scan: WaveScan
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle(title)
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        #if os(macOS)
        .frame(minWidth: 520, idealWidth: 560, minHeight: 520, idealHeight: 640)
        #else
        .presentationDragIndicator(.visible)
        #endif
    }

    private var title: LocalizedStringKey {
        switch kind {
        case .impact: "Impact on Locky"
        case .bluetooth: "Bluetooth around"
        case .wifi: "Wi-Fi"
        case .link: "Link with your iPhone"
        case .sound: "Sound"
        case .magneticField: "Magnetic field"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .impact:
            ImpactDetails(scan: scan)
        case .bluetooth:
            BluetoothDetails(scan: scan)
        case .wifi:
            WiFiDetails(mac: scan.mac)
        case .link:
            LinkDetails(link: scan.mac?.link)
        case .sound:
            SoundDetails(sound: scan.phone?.sound)
        case .magneticField:
            MagneticFieldDetails(field: scan.phone?.magneticField)
        }
    }
}

// MARK: - Impact

private struct ImpactDetails: View {
    let scan: WaveScan

    var body: some View {
        let impact: WaveImpact = scan.impact
        List {
            Section {
                HStack(spacing: 16) {
                    ImpactGauge(score: impact.score, level: impact.level)
                        .frame(width: 72, height: 72)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(impact.level.title)
                            .font(.system(.title2, design: .rounded, weight: .bold))
                            .foregroundStyle(impact.level.color)
                        Text(impact.level.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("Locky estimates the distance from the strength of the Bluetooth signal of your iPhone. Here is what blurs it where you measured.")
            }
            Section {
                ForEach(impact.factors) { factor in
                    WaveFactorRow(factor: factor, scan: scan, isDetailed: true)
                        .padding(.vertical, 4)
                }
            } footer: {
                Text(WaveFactorText.harmless)
            }
        }
    }
}

// MARK: - Bluetooth

private struct BluetoothDetails: View {
    let scan: WaveScan

    private enum Source: Hashable {
        case mac
        case phone
        case classic
    }

    @State private var source: Source = .mac

    var body: some View {
        List {
            Section {
                Picker("Heard by", selection: $source) {
                    if scan.mac != nil {
                        Text("Mac").tag(Source.mac)
                    }
                    if scan.phone != nil {
                        Text("iPhone").tag(Source.phone)
                    }
                    if scan.mac != nil {
                        Text("Classic").tag(Source.classic)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .listRowBackground(Color.clear)
            } footer: {
                Text(footer)
            }
            switch source {
            case .mac:
                neighbors(scan.mac?.bluetoothDevices ?? [])
            case .phone:
                neighbors(scan.phone?.bluetoothDevices ?? [])
            case .classic:
                classic(scan.mac?.classicDevices ?? [])
            }
        }
        .onAppear {
            if scan.mac == nil {
                source = .phone
            }
        }
    }

    private var footer: LocalizedStringKey {
        switch source {
        case .mac, .phone:
            "Bluetooth Low Energy: watches, headphones, trackers, phones… Many change their address every few minutes, so one device may show up twice."
        case .classic:
            "Classic Bluetooth: speakers, headphones, cars, keyboards… Connected ones share the Bluetooth radio of your Mac with Locky."
        }
    }

    @ViewBuilder
    private func neighbors(_ devices: [BluetoothNeighbor]) -> some View {
        Section {
            if devices.isEmpty {
                Text("No device heard.")
                    .foregroundStyle(.secondary)
            }
            ForEach(devices) { device in
                HStack(spacing: 12) {
                    Circle()
                        .fill(BluetoothRadarView.color(device))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: device.displayName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        Text(verbatim: details(device))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        SignalBars(rssi: device.rssi)
                        Text(verbatim: WaveFormat.dBm(device.rssi))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Devices: \(devices.count)")
        }
    }

    private func details(_ device: BluetoothNeighbor) -> String {
        var parts: [String] = []
        if let company = device.company, device.name != nil {
            parts.append(company.name)
        }
        if device.isNearby {
            parts.append(String(localized: "close by"))
        }
        parts.append(String(localized: "heard \(device.sightings) times"))
        return parts.joined(separator: " · ")
    }

    @ViewBuilder
    private func classic(_ devices: [ClassicBluetoothDevice]) -> some View {
        Section {
            if devices.isEmpty {
                Text("No device found.")
                    .foregroundStyle(.secondary)
            }
            ForEach(devices) { device in
                HStack(spacing: 12) {
                    Image(systemName: device.kind.systemImage)
                        .foregroundStyle(device.isConnected ? Color.accentColor : .secondary)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: device.name ?? device.id)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(device.kind.title)
                            if device.isConnected {
                                Text(verbatim: "·")
                                Text("connected to your Mac")
                            } else if device.isPaired {
                                Text(verbatim: "·")
                                Text("paired")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }
                    Spacer()
                    if let rssi = device.rssi {
                        VStack(alignment: .trailing, spacing: 2) {
                            SignalBars(rssi: rssi)
                            Text(verbatim: WaveFormat.dBm(rssi))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            Text("Devices: \(devices.count)")
        }
    }
}

// MARK: - Wi-Fi

private struct WiFiDetails: View {
    let mac: MacWaveCapture?

    var body: some View {
        List {
            if let connection = mac?.wifiConnection {
                Section("Your Mac") {
                    if let ssid = connection.ssid {
                        LabeledContent("Network", value: ssid)
                    }
                    LabeledContent("Band", value: WaveFormat.band(connection.band))
                    LabeledContent("Channel", value: "\(connection.channel) · \(WaveFormat.megahertz(connection.channelWidth))")
                    LabeledContent("Signal", value: WaveFormat.dBm(connection.rssi))
                    LabeledContent("Noise", value: WaveFormat.dBm(connection.noise))
                    LabeledContent("Signal above the noise", value: WaveFormat.decibels(Double(connection.signalToNoise)))
                    LabeledContent("Rate", value: WaveFormat.rate(connection.transmitRate))
                    if let generation = connection.generation {
                        LabeledContent("Standard", value: "Wi-Fi \(generation)")
                    }
                }
            }
            if mac?.areNetworkNamesHidden == true {
                Section {
                    Label("macOS hides the names of the networks: allow Locky in System Settings › Privacy & Security › Location Services.", systemImage: "location.slash")
                        .font(.footnote)
                }
            }
            ForEach(WiFiBand.allCases, id: \.self) { band in
                let networks: [WiFiNetwork] = mac?.wifiNetworks.filter { $0.band == band } ?? []
                if !networks.isEmpty {
                    Section {
                        ForEach(networks) { network in
                            row(network, in: networks)
                        }
                    } header: {
                        Text(verbatim: "\(WaveFormat.band(band)) · \(networks.count)")
                    } footer: {
                        if band == .ghz2_4 {
                            Text("Bluetooth shares this band: the strong networks here weigh on the link of Locky.")
                        }
                    }
                }
            }
        }
    }

    private func row(_ network: WiFiNetwork, in networks: [WiFiNetwork]) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(WiFiSpectrumChart.color(network, in: Array(networks.prefix(24))))
                .frame(width: 10, height: 10)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(verbatim: network.displayName)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if network.isCurrent {
                        Text("Your Mac")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.2), in: .capsule)
                    }
                }
                Text(verbatim: [
                    String(localized: "channel \(network.channel)"),
                    WaveFormat.megahertz(network.channelWidth),
                    network.security.title,
                    network.bssid
                ].compactMap(\.self).joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                SignalBars(rssi: network.rssi)
                Text(verbatim: WaveFormat.dBm(network.rssi))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Link

private struct LinkDetails: View {
    let link: LinkQuality?

    var body: some View {
        List {
            if let link {
                Section {
                    LinkQualityChart(link: link)
                        .padding(.vertical, 6)
                }
                Section {
                    LabeledContent("Average signal", value: WaveFormat.dBm(link.averageRSSI))
                    LabeledContent("Steadiness", value: WaveFormat.deviation(link.deviation))
                    LabeledContent("Weakest", value: WaveFormat.dBm(link.samples.min() ?? 0))
                    LabeledContent("Strongest", value: WaveFormat.dBm(link.samples.max() ?? 0))
                    LabeledContent("Readings", value: "\(link.samples.count)")
                    LabeledContent("Dropouts", value: "\(link.dropouts)")
                } footer: {
                    Text("Your Mac read the signal of your iPhone lying next to it, about three times a second. The steadier it is, the more precise the distance; a dropout is more than 1.5 seconds without a reading.")
                }
            } else {
                Text("Your iPhone was not connected to your Mac during this measurement.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sound

private struct SoundDetails: View {
    let sound: SoundSpectrum?

    var body: some View {
        List {
            if let sound {
                Section {
                    SoundSpectrumChart(spectrum: sound)
                        .padding(.vertical, 6)
                }
                Section {
                    LabeledContent("Average level", value: WaveFormat.decibels(sound.averageLevel))
                    LabeledContent("Loudest moment", value: WaveFormat.decibels(sound.peakLevel))
                    if let dominant = sound.dominantFrequency {
                        LabeledContent("Dominant pitch", value: WaveFormat.hertz(dominant))
                    }
                } footer: {
                    Text("Levels in decibels below the loudest sound the microphone of your iPhone can take: the closer to 0, the louder. A quiet room reads around -70 dB, a conversation around -40 dB.")
                }
            } else {
                Text("Locky could not use the microphone of your iPhone.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Magnetic field

private struct MagneticFieldDetails: View {
    let field: MagneticField?

    var body: some View {
        List {
            if let field {
                Section {
                    MagneticFieldChart(field: field)
                        .padding(.vertical, 6)
                }
                Section {
                    LabeledContent("Average", value: WaveFormat.microteslas(field.average))
                    LabeledContent("Strongest", value: WaveFormat.microteslas(field.strongest))
                    LabeledContent("Weakest", value: WaveFormat.microteslas(field.weakest))
                } footer: {
                    if field.isCalibrated {
                        Text("The Earth alone gives 25 to 65 µT (green band). Magnets add a lot right next to them: speakers, and the lid and MagSafe of a MacBook.")
                    } else {
                        Text("Raw readings of the magnetometer: iOS had not calibrated it yet, the iPhone’s own field is included. The Earth alone gives 25 to 65 µT (green band).")
                    }
                }
            } else {
                Text("Your iPhone could not measure the magnetic field.")
                    .foregroundStyle(.secondary)
            }
        }
    }
}
