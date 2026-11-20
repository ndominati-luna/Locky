import Foundation

/// Setup that follows the pairing, in the pairing window. The iPhone follows the same steps.
enum MacSetupStep: Equatable {
    /// Permissions Locky needs, launch at login, then the offer to try Locky.
    case permissions
    /// Guided first try: walk away with the iPhone (the Mac locks), then come back (it unlocks).
    case firstTry
    /// The first try worked.
    case magic
}
