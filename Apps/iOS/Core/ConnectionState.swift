import Foundation

/// Link state between the iPhone and the Mac.
enum ConnectionState: Equatable {
    /// Bluetooth is off.
    case bluetoothOff
    /// Locky is not allowed to use Bluetooth.
    case unauthorized
    /// Bluetooth is not available on this device (simulator).
    case unsupported
    /// Advertising, waiting for the Mac.
    case searching
    /// A Mac is connected, the secure session is being opened.
    case connecting
    /// The secure session is open.
    case connected

    var isConnected: Bool {
        self == .connected
    }
}
