#if DEBUG
import Foundation
import LockyKit

/// Sample measurements of the waves for the simulator (no Bluetooth, no Mac there).
extension DemoMode {
    /// `-LockyDemoWaves measuring|saving|empty`: a measurement under way, or none at all.
    static var wavePhase: WaveScanPhase {
        let run: WaveScanRun = .init(id: .init(), name: "Salon", date: .now, startedAt: .now, isStartedHere: true)
        switch UserDefaults.standard.string(forKey: "LockyDemoWaves") {
        case "measuring": return .measuring(run)
        case "saving": return .saving(run)
        default: return .idle
        }
    }

    static let waveScans: [WaveScan] = UserDefaults.standard.string(forKey: "LockyDemoWaves") == "empty"
        ? []
        : [home, office, cafe]

    private static let home: WaveScan = .init(
        id: .init(uuidString: "6F1B2A3C-0000-4000-8000-000000000001") ?? .init(),
        name: "Maison",
        date: .now.addingTimeInterval(-3_600 * 5),
        mac: .init(
            wifiNetworks: [
                network("Freebox-Maison", rssi: -41, channel: 36, band: .ghz5, width: 80, isCurrent: true),
                network("Freebox-Maison", rssi: -47, channel: 6, band: .ghz2_4, width: 20),
                network("Livebox-7A21", rssi: -78, channel: 1, band: .ghz2_4, width: 20),
                network("SFR_C8D0", rssi: -84, channel: 11, band: .ghz2_4, width: 20),
                network("Freebox-Maison", rssi: -58, channel: 37, band: .ghz6, width: 160),
                network("Livebox-7A21", rssi: -82, channel: 100, band: .ghz5, width: 80)
            ],
            wifiConnection: .init(ssid: "Freebox-Maison", rssi: -41, noise: -96, channel: 36, band: .ghz5, channelWidth: 80, transmitRate: 1_201, generation: 6),
            bluetoothDevices: neighbors(count: 9, strongest: -52, seed: 1),
            classicDevices: [
                .init(id: "4C-87-5D-11-22-33", name: "Enceinte du salon", rssi: -71, kind: .audio, isPaired: true, isConnected: false),
                .init(id: "A4-C3-61-44-55-66", name: "Magic Keyboard", rssi: -48, kind: .peripheral, isPaired: true, isConnected: true)
            ],
            link: link(average: -44, deviation: 0.9)
        ),
        phone: .init(
            bluetoothDevices: neighbors(count: 11, strongest: -50, seed: 2),
            sound: sound(level: -62, hum: 1),
            magneticField: field(average: 52, spread: 4),
            cellular: .fiveG
        )
    )

    private static let office: WaveScan = .init(
        id: .init(uuidString: "6F1B2A3C-0000-4000-8000-000000000002") ?? .init(),
        name: "Bureau",
        date: .now.addingTimeInterval(-86_400 * 2),
        mac: .init(
            wifiNetworks: (0..<14).map { index in
                network(
                    index == 0 ? "Lunabee" : ["Lunabee-Guest", "Cowork-2.4", "DIRECT-HP-Printer", "Bbox-91F2", "Livebox-PRO", "eduroam"][index % 6],
                    rssi: -50 - index * 3,
                    channel: [1, 6, 11, 6, 1, 11, 3, 9, 6, 1, 11, 6, 13, 1][index],
                    band: .ghz2_4,
                    width: index.isMultiple(of: 4) ? 40 : 20,
                    isCurrent: index == 0
                )
            } + [network("Lunabee-5G", rssi: -57, channel: 44, band: .ghz5, width: 80)],
            wifiConnection: .init(ssid: "Lunabee", rssi: -50, noise: -82, channel: 1, band: .ghz2_4, channelWidth: 20, transmitRate: 144, generation: 4),
            bluetoothDevices: neighbors(count: 64, strongest: -45, seed: 3),
            classicDevices: [
                .init(id: "F4-AF-E7-01-02-03", name: "AirPods Pro de Tom", rssi: -39, kind: .audio, isPaired: true, isConnected: true),
                .init(id: "00-1B-66-04-05-06", name: "Jabra Speak", rssi: -66, kind: .audio, isPaired: false, isConnected: false),
                .init(id: "DC-A6-32-07-08-09", name: nil, rssi: -80, kind: .computer, isPaired: false, isConnected: false)
            ],
            link: link(average: -51, deviation: 4.6)
        ),
        phone: .init(
            bluetoothDevices: neighbors(count: 71, strongest: -44, seed: 4),
            sound: sound(level: -41, hum: 0),
            magneticField: field(average: 74, spread: 18),
            cellular: .fourG
        )
    )

    private static let cafe: WaveScan = .init(
        id: .init(uuidString: "6F1B2A3C-0000-4000-8000-000000000003") ?? .init(),
        name: "Café",
        date: .now.addingTimeInterval(-86_400 * 6),
        mac: .init(
            wifiNetworks: [
                network(nil, rssi: -55, channel: 6, band: .ghz2_4, width: 20, isCurrent: true),
                network(nil, rssi: -63, channel: 11, band: .ghz2_4, width: 20),
                network(nil, rssi: -69, channel: 1, band: .ghz2_4, width: 20),
                network(nil, rssi: -73, channel: 6, band: .ghz2_4, width: 20),
                network(nil, rssi: -61, channel: 149, band: .ghz5, width: 80)
            ],
            wifiConnection: .init(ssid: nil, rssi: -55, noise: -88, channel: 6, band: .ghz2_4, channelWidth: 20, transmitRate: 72, generation: 4),
            areNetworkNamesHidden: true,
            bluetoothDevices: neighbors(count: 27, strongest: -58, seed: 5),
            classicDevices: [],
            link: link(average: -47, deviation: 2.3)
        ),
        phone: nil
    )

    private static func network(_ ssid: String?, rssi: Int, channel: Int, band: WiFiBand, width: Int, isCurrent: Bool = false) -> WiFiNetwork {
        .init(
            id: "\(ssid ?? "hidden")-\(channel)-\(band.rawValue)-\(rssi)",
            ssid: ssid,
            bssid: ssid == nil ? nil : String(format: "a4:%02x:%02x:3c:9e:%02x", channel, abs(rssi), width),
            rssi: rssi,
            noise: -92,
            channel: channel,
            band: band,
            channelWidth: width,
            security: ssid == "eduroam" ? .enterprise : .wpa3,
            isCurrent: isCurrent
        )
    }

    private static func neighbors(count: Int, strongest: Int, seed: Int) -> [BluetoothNeighbor] {
        let names: [String?] = ["Apple Watch", nil, "AirPods", nil, "Galaxy Buds2", nil, nil, "Tile", "MX Master 3", nil, "Fitbit Charge", nil]
        let companies: [UInt16?] = [0x004C, 0x004C, 0x004C, 0x0075, 0x0075, 0x0006, nil, nil, nil, 0x004C, nil, 0x00E0]
        return (0..<count).map { index in
            let rssi: Int = strongest - (index * 47 + seed * 13) % 45
            return .init(
                id: "\(seed)-\(index)",
                name: names[(index + seed) % names.count],
                rssi: rssi,
                strongestRSSI: rssi + 4,
                sightings: 20 + (index * 7) % 60,
                companyID: companies[(index * 5 + seed) % companies.count],
                serviceUUIDs: [],
                isConnectable: index.isMultiple(of: 3),
                txPower: nil
            )
        }.sorted { $0.rssi > $1.rssi }
    }

    private static func link(average: Double, deviation: Double) -> LinkQuality {
        let times: [Double] = (0..<64).map { Double($0) * 0.31 }
        let samples: [Double] = times.map { average + deviation * 1.4 * sin($0 * 2.3) * cos($0 * 0.7) }
        return .init(samples: samples, times: times)
    }

    private static func sound(level: Double, hum: Double) -> SoundSpectrum {
        let frequencies: [Double] = SoundSpectrum.bandCenters
        let levels: [Double] = frequencies.map { frequency in
            // Voices around 300 Hz – 3 kHz, the hum of the fridge at 50 Hz.
            let voices: Double = -12 * pow(log2(frequency / 900), 2) / 6
            let humPeak: Double = hum * 14 * exp(-pow(log2(frequency / 50), 2) * 8)
            return level - 8 + max(voices, -40) + humPeak - (frequency > 8_000 ? 10 : 0)
        }
        return .init(frequencies: frequencies, levels: levels, averageLevel: level, peakLevel: level + 14, dominantFrequency: hum > 0 ? 50 : 420)
    }

    private static func field(average: Double, spread: Double) -> MagneticField {
        .init(samples: (0..<200).map { average + spread * sin(Double($0) / 9) * cos(Double($0) / 23) }, isCalibrated: true)
    }
}
#endif
