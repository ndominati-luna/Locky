import Foundation

/// Link state between the Mac and the iPhone.
enum MacConnectionState: Equatable {
    case bluetoothOff
    case unauthorized
    case unsupported
    /// Looking for the iPhone.
    case searching
    /// Bluetooth connected, secure session being opened.
    case connecting
    /// Secure session open.
    case connected

    var isConnected: Bool {
        self == .connected
    }
}
