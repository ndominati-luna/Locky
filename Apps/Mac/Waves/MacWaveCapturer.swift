import Foundation
import LockyKit

/// What the Mac listens to during a measurement of the waves (``WaveScan/captureDuration``):
/// - Wi-Fi, scanned twice (at the start and halfway), each access point keeping its strongest
///   reading;
/// - Bluetooth Low Energy, the whole time;
/// - classic Bluetooth, for about eight seconds, plus the devices paired with the Mac;
/// - the link with the iPhone lying next to it: each signal reading of the session
///   (``recordLink(rssi:)``), three a second.
@MainActor
final class MacWaveCapturer {
    let location: LocationPermission = .init()
    private let neighbors: BluetoothNeighborScanner = .init()
    private let classic: ClassicBluetoothScanner = .init()
    private var linkStart: Date?
    private var linkSamples: [Double] = []
    private var linkTimes: [Double] = []

    /// A reading of the signal of the iPhone, during a measurement.
    func recordLink(rssi: Double) {
        guard let linkStart else { return }
        linkSamples.append(rssi)
        linkTimes.append(Date.now.timeIntervalSince(linkStart))
    }

    func capture(_ run: WaveScanRun) async -> MacWaveCapture {
        let start: Date = .now
        linkStart = start
        linkSamples = []
        linkTimes = []
        neighbors.start()
        // Started from the iPhone: macOS asks on the Mac, the second scan gets the names.
        if !location.isGranted, !location.isDenied {
            Task { await location.request() }
        }
        async let classicDevices: [ClassicBluetoothDevice] = scanClassic()
        var wifi: WiFiScanner.Result = await WiFiScanner.scan()
        await sleep(until: start.addingTimeInterval(Self.duration / 2))
        if !Task.isCancelled {
            wifi = WiFiScanner.merge(wifi, await WiFiScanner.scan())
        }
        await sleep(until: start.addingTimeInterval(Self.duration))
        let classicFound: [ClassicBluetoothDevice] = await classicDevices
        let link: LinkQuality? = linkSamples.count >= 3 ? .init(samples: linkSamples, times: linkTimes) : nil
        linkStart = nil
        return .init(
            wifiNetworks: wifi.networks,
            wifiConnection: wifi.connection,
            areNetworkNamesHidden: wifi.areNamesHidden,
            bluetoothDevices: neighbors.stop(),
            classicDevices: classicFound,
            link: link
        )
    }

    private static var duration: TimeInterval {
        TimeInterval(WaveScan.captureDuration.components.seconds)
    }

    private func scanClassic() async -> [ClassicBluetoothDevice] {
        // After the first Wi-Fi scan got going: both at once would hold the radio longer.
        try? await Task.sleep(for: .seconds(2))
        guard !Task.isCancelled else { return [] }
        return await classic.scan(seconds: 8)
    }

    private func sleep(until date: Date) async {
        let delay: TimeInterval = date.timeIntervalSinceNow
        guard delay > 0 else { return }
        try? await Task.sleep(for: .seconds(delay))
    }
}
