import Foundation

extension AppModel {
    /// "Connected · about 1.3 m", or why the Mac cannot be reached: the chip of the main screen, and
    /// the settings while the Mac is out of reach.
    var connectionSummary: String {
        switch session.connection {
        case .connected:
            guard let distance = proximity?.distance else { return String(localized: "Connected") }
            let formatted: String = Measurement(value: distance, unit: UnitLength.meters).formatted(.lockyDistance)
            return String(localized: "Connected · about \(formatted)")
        case .connecting:
            return String(localized: "Securing the connection…")
        case .searching:
            return String(localized: "Looking for your Mac…")
        case .bluetoothOff:
            return String(localized: "Bluetooth is off")
        case .unauthorized:
            return String(localized: "Bluetooth not allowed")
        case .unsupported:
            return String(localized: "Bluetooth unavailable")
        }
    }
}
