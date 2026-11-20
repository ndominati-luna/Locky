import Foundation

/// Guided first try that follows the pairing, in step with the pairing window of the Mac.
enum SetupPhase: Equatable {
    /// Paired: the user finishes on the Mac (permissions), which starts the first try.
    case waitingForMac
    /// Walk away with the iPhone until the Mac locks.
    case walkAway
    /// The Mac locked: come back, Locky unlocks it.
    case comeBack
    /// Locky locked then unlocked the Mac.
    case magic
}
