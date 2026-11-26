import LockyKit
import SwiftUI

/// Why a measurement of the waves cannot start, on the Mac or on the iPhone.
enum WaveScanBlocker: Equatable {
    case notPaired
    /// The other device is out of reach: both are needed.
    case peerOutOfReach
    /// The other device runs a version of Locky that cannot measure the waves.
    case peerTooOld
    /// Started from the Mac: Locky must be on the screen of the iPhone (iOS lets it listen only
    /// then).
    case phoneNotOnScreen

    var message: LocalizedStringKey {
        switch self {
        case .notPaired:
            "Pair your iPhone with your Mac first."
        case .peerOutOfReach:
            #if os(macOS)
            "Your iPhone is out of reach: bring it next to your Mac."
            #else
            "Your Mac is out of reach: get next to it."
            #endif
        case .peerTooOld:
            #if os(macOS)
            "Update Locky on your iPhone to measure the waves."
            #else
            "Update Locky on your Mac to measure the waves."
            #endif
        case .phoneNotOnScreen:
            "Open Locky on your iPhone: it listens only while it is on screen."
        }
    }
}

extension WaveImpact.Level {
    var color: Color {
        switch self {
        case .calm: .green
        case .busy: .orange
        case .crowded: .red
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .calm: "Calm"
        case .busy: "Busy"
        case .crowded: "Crowded"
        }
    }

    var summary: LocalizedStringKey {
        switch self {
        case .calm: "Nothing gets in the way: Locky measures the distance precisely here."
        case .busy: "Some traffic: the distance may waver a little, Locky may lock a few seconds later."
        case .crowded: "Lots of waves: Locky may lock or unlock late here."
        }
    }

    var systemImage: String {
        switch self {
        case .calm: "checkmark.circle.fill"
        case .busy: "exclamationmark.circle.fill"
        case .crowded: "exclamationmark.triangle.fill"
        }
    }
}

extension WaveImpact.Kind {
    var title: LocalizedStringKey {
        switch self {
        case .link: "Link with your iPhone"
        case .bluetooth: "Bluetooth around"
        case .wifi: "Wi-Fi at 2.4 GHz"
        case .macBluetooth: "Devices connected to your Mac"
        }
    }

    var systemImage: String {
        switch self {
        case .link: "link"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .wifi: "wifi"
        case .macBluetooth: "headphones"
        }
    }
}

/// Formats for the values measured.
enum WaveFormat {
    static func dBm(_ value: Int) -> String {
        "\(value) dBm"
    }

    static func dBm(_ value: Double) -> String {
        "\(Int(value.rounded())) dBm"
    }

    static func decibels(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) dB"
    }

    static func deviation(_ value: Double) -> String {
        "±\(value.formatted(.number.precision(.fractionLength(1)))) dB"
    }

    static func microteslas(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)))) µT"
    }

    static func megahertz(_ value: Int) -> String {
        "\(value) MHz"
    }

    static func hertz(_ value: Double) -> String {
        value >= 1000
            ? "\((value / 1000).formatted(.number.precision(.fractionLength(value >= 10_000 ? 0 : 1)))) kHz"
            : "\(Int(value.rounded())) Hz"
    }

    static func rate(_ value: Double) -> String {
        "\(Int(value.rounded())) Mbit/s"
    }

    static func band(_ band: WiFiBand) -> String {
        switch band {
        case .ghz2_4: "2.4 GHz".localizedDecimals
        case .ghz5: "5 GHz"
        case .ghz6: "6 GHz"
        }
    }

    /// Bars from 0 to 4 for a signal in dBm.
    static func bars(_ rssi: Int) -> Int {
        if rssi >= -55 {
            4
        } else if rssi >= -67 {
            3
        } else if rssi >= -78 {
            2
        } else if rssi >= -88 {
            1
        } else {
            0
        }
    }
}

private extension String {
    /// "2.4" written with the decimal separator of the user ("2,4" in French).
    var localizedDecimals: String {
        replacing(".", with: Locale.current.decimalSeparator ?? ".")
    }
}

/// A Wi-Fi network named for people: its name, or what it is when macOS hides it.
extension WiFiNetwork {
    var displayName: String {
        if let ssid, !ssid.isEmpty {
            return ssid
        }
        return bssid == nil ? String(localized: "Name hidden by macOS") : String(localized: "Hidden network")
    }
}

extension BluetoothNeighbor {
    var displayName: String {
        name ?? company.map { String(localized: "\($0.name) device") } ?? String(localized: "Unnamed device")
    }
}

extension WiFiSecurity {
    var title: String {
        switch self {
        case .open: String(localized: "No password")
        case .wep: "WEP"
        case .wpa: "WPA"
        case .wpa2: "WPA2"
        case .wpa3: "WPA3"
        case .enterprise: String(localized: "Enterprise")
        case .unknown: String(localized: "Unknown")
        }
    }
}

extension BluetoothDeviceKind {
    var title: LocalizedStringKey {
        switch self {
        case .computer: "Computer"
        case .phone: "Phone"
        case .network: "Network"
        case .audio: "Audio"
        case .peripheral: "Keyboard, mouse…"
        case .imaging: "Printer, camera…"
        case .wearable: "Wearable"
        case .toy: "Toy"
        case .health: "Health"
        case .other: "Other"
        }
    }
}

/// A glass card of a measurement: a small title, an optional button to its details, its content.
struct WaveCard<Content: View>: View {
    let title: LocalizedStringKey
    let systemImage: String
    var showDetails: (() -> Void)?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(title, systemImage: systemImage)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let showDetails {
                    Button(action: showDetails) {
                        HStack(spacing: 2) {
                            Text("Details")
                            Image(systemName: "chevron.right")
                                .imageScale(.small)
                        }
                        .font(.footnote.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.tint)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 26))
    }
}

/// A value measured and what it is, side by side in a card.
struct WaveMetric: View {
    let value: String
    let label: LocalizedStringKey
    var tint: Color = .primary

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value)
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundStyle(tint)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Signal bars, like those of Wi-Fi in the menu bar.
struct SignalBars: View {
    let rssi: Int

    var body: some View {
        let bars: Int = WaveFormat.bars(rssi)
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<4) { index in
                Capsule()
                    .fill(index < bars ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: 3, height: 5 + CGFloat(index) * 3)
            }
        }
        .accessibilityHidden(true)
    }
}
