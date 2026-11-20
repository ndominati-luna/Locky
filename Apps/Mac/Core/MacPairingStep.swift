import Foundation

/// Progress of the pairing as displayed in the pairing window.
enum MacPairingStep: Equatable {
    /// Not pairing.
    case idle
    /// Looking for an iPhone running Locky.
    case searching
    /// An iPhone answered; the user must confirm it is theirs.
    case deviceFound(name: String, modelIdentifier: String)
    /// Both screens display the code: the user must confirm it on the Mac *and* on the iPhone.
    case confirmCode(code: String, deviceName: String, isConfirmedOnMac: Bool, isConfirmedOnPhone: Bool)
    /// Waiting for the session password.
    case password(deviceName: String)
    /// Measuring the signal with the iPhone next to the Mac.
    case calibrating
    /// Paired.
    case completed
    /// Failed, must be restarted.
    case failed(String)
}
