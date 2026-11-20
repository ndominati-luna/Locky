import LockyKit
import SwiftUI

/// Custom view at the top of the status menu, like the original Locky menu: the paired iPhone and
/// the "Locky activated" switch.
struct StatusMenuHeader: View {
    @Environment(MacAppModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhoneHeader()
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Locky activated")
                        .font(.headline)
                    Text("Lock when my iPhone walks away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("Locky activated", isOn: Binding(get: { model.preferences.isAutoLockEnabled }, set: model.setAutoLockEnabled))
                    .toggleStyle(MenuSwitchToggleStyle())
                    .labelsHidden()
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 300)
    }
}

/// Paired iPhone: picture, name, connection, battery and distance.
private struct PhoneHeader: View {
    @Environment(MacAppModel.self) private var model

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = model.phoneImage {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "iphone")
                        .font(.largeTitle)
                }
            }
            .frame(width: 34, height: 52)
            .opacity(model.session.connection.isConnected ? 1 : 0.4)

            VStack(alignment: .leading, spacing: 3) {
                Text(model.phoneName)
                    .font(.headline)
                Label(connectionText, systemImage: model.session.connection.isConnected ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(model.session.connection.isConnected ? .green : .secondary)
                if model.session.connection.isConnected, let proximity = model.proximity {
                    Text("About \(Measurement(value: proximity.distance, unit: UnitLength.meters), format: .lockyDistance) away")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            Spacer()
            if let level = model.batteryLevel {
                Label("\(level)%", systemImage: batterySymbol(level))
                    .font(.caption)
                    .foregroundStyle(level <= 20 ? .red : .secondary)
                    .monospacedDigit()
            }
        }
    }

    private var connectionText: LocalizedStringKey {
        switch model.session.connection {
        case .connected: "Connected"
        case .connecting: "Connecting…"
        case .searching: "Out of reach"
        case .bluetoothOff: "Bluetooth is off"
        case .unauthorized: "Bluetooth not allowed"
        case .unsupported: "Bluetooth unavailable"
        }
    }

    private func batterySymbol(_ level: Int) -> String {
        switch level {
        case ..<10: "battery.0percent"
        case ..<40: "battery.25percent"
        case ..<65: "battery.50percent"
        case ..<90: "battery.75percent"
        default: "battery.100percent"
        }
    }
}
