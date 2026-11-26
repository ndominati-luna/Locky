import CryptoKit
import Foundation
import Testing
@testable import LockyKit

/// Measurements of the waves around: sealed for iCloud, merged, judged for Locky.
struct WaveScanTests {
    private static let macID: UUID = .init()

    private static func network(_ ssid: String, rssi: Int, channel: Int, band: WiFiBand, width: Int = 20, isCurrent: Bool = false) -> WiFiNetwork {
        .init(
            id: UUID().uuidString,
            ssid: ssid,
            bssid: nil,
            rssi: rssi,
            noise: -92,
            channel: channel,
            band: band,
            channelWidth: width,
            security: .wpa2,
            isCurrent: isCurrent
        )
    }

    private static func neighbor(rssi: Int) -> BluetoothNeighbor {
        .init(
            id: UUID().uuidString,
            name: nil,
            rssi: rssi,
            strongestRSSI: rssi + 3,
            sightings: 12,
            companyID: BluetoothCompany.apple.rawValue,
            serviceUUIDs: [],
            isConnectable: false,
            txPower: nil
        )
    }

    private static func link(deviation: Double, count: Int = 60) -> LinkQuality {
        let samples: [Double] = (0..<count).map { -45 + ($0.isMultiple(of: 2) ? deviation : -deviation) }
        return .init(samples: samples, times: (0..<count).map { Double($0) * 0.3 })
    }

    private static func macPart(_ capture: MacWaveCapture, scanID: UUID = .init()) -> WaveScanPart {
        .init(scanID: scanID, name: "Maison", date: .init(timeIntervalSinceReferenceDate: 800_000_000), capture: .mac(capture))
    }

    // MARK: - Sealing

    @Test
    func sealedRoundTrip() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let part: WaveScanPart = Self.macPart(.init(
            wifiNetworks: [Self.network("Freebox-Maison", rssi: -48, channel: 6, band: .ghz2_4, isCurrent: true)],
            bluetoothDevices: [Self.neighbor(rssi: -60)],
            link: Self.link(deviation: 1)
        ))
        let sealed: Data = try part.sealed(key: key, macID: Self.macID)
        #expect(try WaveScanPart(sealed: sealed, key: key, macID: Self.macID) == part)
        // Neither the place nor the networks around are readable in iCloud.
        #expect(sealed.range(of: Data("Maison".utf8)) == nil)
        #expect(sealed.range(of: Data("Freebox".utf8)) == nil)
    }

    @Test
    func otherKeyOrMacIsRefused() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let sealed: Data = try Self.macPart(.init()).sealed(key: key, macID: Self.macID)
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try WaveScanPart(sealed: sealed, key: .init(size: .bits256), macID: Self.macID)
        }
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try WaveScanPart(sealed: sealed, key: key, macID: .init())
        }
    }

    /// Sealed settings never open as a measurement, nor the other way round.
    @Test
    func labelsKeepKindsApart() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let settings: Data = try MacSettingsEnvelope(autoLock: .init(true)).sealed(key: key, macID: Self.macID)
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try WaveScanPart(sealed: settings, key: key, macID: Self.macID)
        }
        let waves: Data = try Self.macPart(.init()).sealed(key: key, macID: Self.macID)
        #expect(throws: LockyProtocolError.authenticationFailed) {
            try MacSettingsEnvelope(sealed: waves, key: key, macID: Self.macID)
        }
    }

    // MARK: - Merging

    @Test
    func partsMergeIntoOneScan() {
        let scanID: UUID = .init()
        let older: WaveScanPart = .init(scanID: .init(), name: "Bureau", date: .init(timeIntervalSinceReferenceDate: 700_000_000), capture: .phone(.init()))
        let mac: WaveScanPart = Self.macPart(.init(areNetworkNamesHidden: true), scanID: scanID)
        let phone: WaveScanPart = .init(scanID: scanID, name: "Maison", date: mac.date, capture: .phone(.init(cellular: .fiveG)))
        let scans: [WaveScan] = WaveScan.merging([phone, older, mac])
        #expect(scans.map(\.name) == ["Maison", "Bureau"])
        #expect(scans.first?.mac?.areNetworkNamesHidden == true)
        #expect(scans.first?.phone?.cellular == .fiveG)
        #expect(scans.last?.mac == nil)
    }

    // MARK: - Impact

    @Test
    func quietPlaceIsCalm() {
        let scan: WaveScan = .init(
            id: .init(),
            name: "Chalet",
            date: .now,
            mac: .init(
                wifiNetworks: [Self.network("Chalet", rssi: -55, channel: 36, band: .ghz5, width: 80, isCurrent: true)],
                wifiConnection: .init(ssid: "Chalet", rssi: -55, noise: -95, channel: 36, band: .ghz5, channelWidth: 80, transmitRate: 864, generation: 6),
                bluetoothDevices: [Self.neighbor(rssi: -85)],
                link: Self.link(deviation: 0.8)
            ),
            phone: .init(bluetoothDevices: [Self.neighbor(rssi: -88)])
        )
        let impact: WaveImpact = scan.impact
        #expect(impact.level == .calm)
        #expect(impact.factors.map(\.kind) == [.link, .bluetooth, .wifi, .macBluetooth])
        #expect(impact.factors.allSatisfy { $0.level == .calm })
    }

    @Test
    func crowdedPlaceIsCrowded() {
        let networks: [WiFiNetwork] = (0..<12).map { Self.network("Voisin \($0)", rssi: -60, channel: [1, 6, 11][$0 % 3], band: .ghz2_4) }
        let scan: WaveScan = .init(
            id: .init(),
            name: "Open space",
            date: .now,
            mac: .init(
                wifiNetworks: networks,
                wifiConnection: .init(ssid: "Voisin 0", rssi: -60, noise: -80, channel: 1, band: .ghz2_4, channelWidth: 20, transmitRate: 72, generation: 4),
                bluetoothDevices: (0..<90).map { _ in Self.neighbor(rssi: -65) },
                classicDevices: [.init(id: "aa", name: "AirPods", rssi: -40, kind: .audio, isPaired: true, isConnected: true)],
                link: Self.link(deviation: 6)
            )
        )
        let impact: WaveImpact = scan.impact
        #expect(impact.level == .crowded)
        #expect(impact.factor(.link)?.level == .crowded)
        #expect(impact.factor(.wifi)?.level == .crowded)
        #expect(impact.factor(.bluetooth)?.level == .crowded)
        #expect(impact.factor(.macBluetooth)?.level == .busy)
    }

    /// A steady link does not hide a Mac on crowded 2.4 GHz Wi-Fi: the place is at least busy.
    @Test
    func worstFactorRaisesTheVerdict() {
        let networks: [WiFiNetwork] = [-55, -63, -69, -73].map { Self.network("Café", rssi: $0, channel: 6, band: .ghz2_4) }
        let scan: WaveScan = .init(
            id: .init(),
            name: "Café",
            date: .now,
            mac: .init(
                wifiNetworks: networks,
                wifiConnection: .init(ssid: "Café", rssi: -55, noise: -88, channel: 6, band: .ghz2_4, channelWidth: 20, transmitRate: 72, generation: 4),
                bluetoothDevices: [Self.neighbor(rssi: -80)],
                link: Self.link(deviation: 0.5)
            )
        )
        let impact: WaveImpact = scan.impact
        #expect(impact.factor(.wifi)?.level == .crowded)
        #expect(impact.factor(.link)?.level == .calm)
        #expect(impact.level == .busy)
    }

    /// Without the Mac, only the Bluetooth around can be judged.
    @Test
    func phoneOnlyJudgesBluetooth() {
        let scan: WaveScan = .init(id: .init(), name: "", date: .now, phone: .init(bluetoothDevices: [Self.neighbor(rssi: -60)]))
        #expect(scan.impact.factors.map(\.kind) == [.bluetooth])
        #expect(WaveScan(id: .init(), name: "", date: .now).impact.factors.isEmpty)
    }

    @Test
    func linkQualityCountsDropouts() {
        let link: LinkQuality = .init(samples: [-40, -42, -44, -42], times: [0, 0.3, 2.5, 2.8])
        #expect(link.averageRSSI == -42)
        #expect(abs(link.deviation - 1.414) < 0.01)
        #expect(link.dropouts == 1)
    }

    // MARK: - Wi-Fi

    @Test
    func channelFrequencies() {
        #expect(WiFiBand.ghz2_4.frequency(ofChannel: 1) == 2412)
        #expect(WiFiBand.ghz2_4.frequency(ofChannel: 14) == 2484)
        #expect(WiFiBand.ghz5.frequency(ofChannel: 36) == 5180)
        #expect(WiFiBand.ghz6.frequency(ofChannel: 1) == 5955)
    }

    @Test
    func wideChannelsBondTheirGroup() {
        #expect(Self.network("", rssi: -50, channel: 44, band: .ghz5, width: 80).centerChannel == 42)
        #expect(Self.network("", rssi: -50, channel: 44, band: .ghz5, width: 40).centerChannel == 46)
        #expect(Self.network("", rssi: -50, channel: 157, band: .ghz5, width: 80).centerChannel == 155)
        #expect(Self.network("", rssi: -50, channel: 52, band: .ghz5, width: 160).centerChannel == 50)
        #expect(Self.network("", rssi: -50, channel: 5, band: .ghz6, width: 160).centerChannel == 15)
        #expect(Self.network("", rssi: -50, channel: 6, band: .ghz2_4, width: 40).centerChannel == 6)
        #expect(Self.network("", rssi: -50, channel: 36, band: .ghz5, width: 80).frequencySpan == 5170...5250)
    }

    // MARK: - Sound

    @Test
    func soundFindsItsTone() throws {
        let sampleRate: Double = 48_000
        let analyzer: SoundAnalyzer = .init(sampleRate: sampleRate)
        let samples: [Float] = (0..<(SoundAnalyzer.windowSize * 6)).map { Float(0.5 * sin(2 * Double.pi * 1000 * Double($0) / sampleRate)) }
        analyzer.add(samples)
        let spectrum: SoundSpectrum = try #require(analyzer.spectrum())
        #expect(abs((spectrum.dominantFrequency ?? 0) - 1000) < 12)
        // A sine of 0.5 has a mean square of 0.125: -9 dB, all of it in the band of 1 kHz.
        #expect(abs(spectrum.averageLevel - -9.03) < 0.1)
        let band: Int = try #require(spectrum.frequencies.firstIndex { abs($0 - 1000) < 1 })
        #expect(abs(spectrum.levels[band] - -9.03) < 0.5)
        #expect(spectrum.levels.enumerated().allSatisfy { $0.offset == band || $0.element < spectrum.levels[band] - 10 })
    }

    // MARK: - Small things

    @Test
    func deviceKindsAndNetworks() {
        // A headset: major class 4 (audio/video).
        #expect(BluetoothDeviceKind(classOfDevice: 0x240404) == .audio)
        #expect(BluetoothDeviceKind(classOfDevice: 0x5A020C) == .phone)
        #expect(CellularTechnology(radioAccessTechnology: "CTRadioAccessTechnologyNRNSA") == .fiveG)
        #expect(CellularTechnology(radioAccessTechnology: "CTRadioAccessTechnologyLTE") == .fourG)
        #expect(CellularTechnology(radioAccessTechnology: "Unknown") == nil)
    }

    @Test
    func signalsRoundTrip() throws {
        let key: SymmetricKey = .init(size: .bits256)
        let macNonce: Data = .randomBytes(count: 32)
        let phoneNonce: Data = .randomBytes(count: 32)
        var phone: SecureChannel = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .phone)
        var mac: SecureChannel? = .init(pairingKey: key, macNonce: macNonce, phoneNonce: phoneNonce, role: .mac)
        let id: UUID = .init()
        let signals: [WaveScanSignal] = [
            .start(id: id, name: "Bureau", date: .init(timeIntervalSinceReferenceDate: 800_000_000)),
            .saved(id: id),
            .declined(id: id),
            .cancelled(id: id)
        ]
        for signal in signals {
            let payload: Data = try WireCodec.encodeEncrypted(.waveScan(signal), channel: &phone)
            #expect(try WireCodec.decode(payload, channel: &mac) == .waveScan(signal))
            // A micro message: the link is never held.
            #expect(payload.count < 200)
        }
        #expect(LockyFeature.current.contains("waveScan"))
    }

    // MARK: - Coordination

    @MainActor
    private final class SignalLog {
        var signals: [WaveScanSignal] = []
    }

    @MainActor
    private static func center(log: SignalLog, canTakePart: Bool = true) -> WaveScanCenter {
        let center: WaveScanCenter = .init(side: .mac)
        center.sendSignal = { signal in
            log.signals.append(signal)
            return true
        }
        center.canTakePart = { canTakePart }
        center.captureHandler = { _ in
            try? await Task.sleep(for: .seconds(30))
            return .mac(.init())
        }
        return center
    }

    /// Cancelled on the other device: stopped here too, without answering.
    @MainActor
    @Test
    func cancelledElsewhereStopsHere() {
        let log: SignalLog = .init()
        let center: WaveScanCenter = Self.center(log: log)
        let id: UUID = .init()
        center.receive(.start(id: id, name: "Bureau", date: .now))
        #expect(center.isMeasuring)
        center.receive(.cancelled(id: id))
        #expect(center.phase == .idle)
        #expect(log.signals.isEmpty)
    }

    /// The other device cannot take part: this one measures alone, and says so.
    @MainActor
    @Test
    func declinedMeasuresAlone() throws {
        let log: SignalLog = .init()
        let center: WaveScanCenter = Self.center(log: log)
        #expect(center.start(name: "Maison"))
        let id: UUID = try #require(center.phase.run?.id)
        center.receive(.declined(id: id))
        #expect(center.isMeasuring)
        #expect(center.isPeerMissing)
        center.cancel()
        #expect(log.signals.last == .cancelled(id: id))
    }

    /// Not on screen (iPhone), or already measuring: the other device is told at once.
    @MainActor
    @Test
    func unavailableDeviceDeclines() {
        let log: SignalLog = .init()
        let center: WaveScanCenter = Self.center(log: log, canTakePart: false)
        let id: UUID = .init()
        center.receive(.start(id: id, name: "Café", date: .now))
        #expect(center.phase == .idle)
        #expect(log.signals == [.declined(id: id)])
    }
}
