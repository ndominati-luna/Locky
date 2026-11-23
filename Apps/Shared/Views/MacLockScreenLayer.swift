import LockyKit
import SwiftUI

/// The imitation of the macOS lock screen over the display of the Mac while it is locked: it fades
/// in when locking and zooms out of the way when unlocking, like macOS.
struct MacLockScreenLayer: View {
    let lockState: LockState
    var userPicture: Data?
    var userName: String?
    /// Locky is typing the password on the Mac: dots appear in the password field.
    var isUnlocking: Bool = false

    var body: some View {
        if lockState == .locked {
            MacLockScreenView(userPicture: userPicture, userName: userName, isUnlocking: isUnlocking)
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.06))))
        }
    }
}
