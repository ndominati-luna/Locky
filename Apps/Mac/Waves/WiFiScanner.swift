import CoreWLAN
import Foundation
import LockyKit

/// The Wi-Fi networks around the Mac and its own connection (CoreWLAN).
///
/// A scan takes the Wi-Fi of the Mac off its channel for a moment, channel after channel: a video
/// call may hiccup. macOS hides the names and addresses of the networks from an app that may not use
/// Location Services (``LocationPermission``).
enum WiFiScanner {
    struct Result: Sendable {
        var networks: [WiFiNetwork]
        var connection: WiFiConnection?
        var areNamesHidden: Bool
    }

    /// Scans once, off the main thread (a scan blocks for a few seconds).
    static func scan() async -> Result {
        await Task.detached(priority: .userInitiated) {
            scanNow()
        }.value
    }

    /// Merges two scans: each access point keeps its strongest reading.
    static func merge(_ first: Result, _ second: Result) -> Result {
        var networks: [String: WiFiNetwork] = [:]
        for network in first.networks + second.networks {
            if let known = networks[network.id], known.rssi >= network.rssi { continue }
            networks[network.id] = network
        }
        return .init(
            networks: sorted(Array(networks.values)),
            connection: second.connection ?? first.connection,
            areNamesHidden: first.areNamesHidden && second.areNamesHidden
        )
    }

    private static func scanNow() -> Result {
        guard let interface = CWWiFiClient.shared().interface(), interface.powerOn() else {
            return .init(networks: [], connection: nil, areNamesHidden: false)
        }
        let connection: WiFiConnection? = connection(of: interface)
        let found: Set<CWNetwork> = (try? interface.scanForNetworks(withSSID: nil, includeHidden: true)) ?? []
        let currentBSSID: String? = interface.bssid()
        var networks: [WiFiNetwork] = []
        for (index, network) in found.enumerated() {
            guard let channel = network.wlanChannel, let band = band(channel.channelBand) else { continue }
            let isCurrent: Bool = currentBSSID != nil && network.bssid == currentBSSID
                || currentBSSID == nil && connection.map { $0.channel == channel.channelNumber && network.rssiValue == $0.rssi } == true
            networks.append(.init(
                id: network.bssid ?? "network-\(index)-\(channel.channelNumber)",
                ssid: network.ssid,
                bssid: network.bssid,
                rssi: network.rssiValue,
                noise: network.noiseMeasurement == 0 ? nil : network.noiseMeasurement,
                channel: channel.channelNumber,
                band: band,
                channelWidth: width(channel.channelWidth),
                security: security(network),
                isCurrent: isCurrent
            ))
        }
        // Names and addresses are all missing when macOS hides them.
        let areNamesHidden: Bool = !networks.isEmpty && networks.allSatisfy { $0.ssid == nil && $0.bssid == nil }
        return .init(networks: sorted(networks), connection: connection, areNamesHidden: areNamesHidden)
    }

    private static func connection(of interface: CWInterface) -> WiFiConnection? {
        guard let channel = interface.wlanChannel(), let band = band(channel.channelBand), interface.rssiValue() != 0 else { return nil }
        return .init(
            ssid: interface.ssid(),
            rssi: interface.rssiValue(),
            noise: interface.noiseMeasurement(),
            channel: channel.channelNumber,
            band: band,
            channelWidth: width(channel.channelWidth),
            transmitRate: interface.transmitRate(),
            generation: generation(interface.activePHYMode())
        )
    }

    private static func sorted(_ networks: [WiFiNetwork]) -> [WiFiNetwork] {
        networks.sorted { $0.rssi > $1.rssi }
    }

    private static func band(_ band: CWChannelBand) -> WiFiBand? {
        switch band {
        case .band2GHz: .ghz2_4
        case .band5GHz: .ghz5
        case .band6GHz: .ghz6
        default: nil
        }
    }

    private static func width(_ width: CWChannelWidth) -> Int {
        switch width {
        case .width40MHz: 40
        case .width80MHz: 80
        case .width160MHz: 160
        default: 20
        }
    }

    private static func generation(_ mode: CWPHYMode) -> Int? {
        switch mode {
        case .mode11n: 4
        case .mode11ac: 5
        case .mode11ax: 6
        case .mode11be: 7
        default: nil
        }
    }

    private static func security(_ network: CWNetwork) -> WiFiSecurity {
        if network.supportsSecurity(.wpa3Personal) || network.supportsSecurity(.wpa3Transition) {
            return .wpa3
        }
        if network.supportsSecurity(.wpa2Enterprise) || network.supportsSecurity(.wpa3Enterprise)
            || network.supportsSecurity(.wpaEnterprise) || network.supportsSecurity(.enterprise) {
            return .enterprise
        }
        if network.supportsSecurity(.wpa2Personal) || network.supportsSecurity(.personal) {
            return .wpa2
        }
        if network.supportsSecurity(.wpaPersonal) || network.supportsSecurity(.wpaPersonalMixed) {
            return .wpa
        }
        if network.supportsSecurity(.WEP) || network.supportsSecurity(.dynamicWEP) {
            return .wep
        }
        if network.supportsSecurity(.none) {
            return .open
        }
        return .unknown
    }
}
