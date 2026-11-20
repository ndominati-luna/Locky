import Foundation
import LockyKit

/// Progress of the pairing as displayed on the iPhone.
enum PairingStep: Equatable {
    /// Waiting for a Mac to start a pairing.
    case waitingForMac
    /// A Mac contacted the iPhone; the user must click "Pair" on the Mac.
    case macFound(name: String, family: MacFamily)
    /// Both devices display the same code; the user must confirm it on the iPhone.
    case confirmCode(code: String, macName: String)
    /// Waiting for the user to type their session password on the Mac.
    case waitingForPassword(macName: String)
    /// The user puts the iPhone about 1 m (then 2 m) from the Mac and confirms.
    case calibrating(CalibrationStep)
    /// The Mac measures the signal (then the iPhone its motion sensors, after the last step).
    case measuring(CalibrationStep)
    /// Done.
    case completed
    /// Something went wrong, the pairing must be restarted from the Mac.
    case failed(String)
}
