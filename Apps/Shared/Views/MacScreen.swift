import LockyKit
import SwiftUI

/// What the display of the paired Mac shows: its wallpaper (black without one), then its lock
/// screen. The black fill sets the size: a wallpaper scaled to fill would otherwise widen the
/// screen past its border.
struct MacScreen: View {
    var wallpaper: UIImage?
    let lockState: LockState
    var userPicture: Data?
    var userName: String?
    var isUnlocking: Bool = false

    var body: some View {
        Color.black
            .overlay {
                if let wallpaper {
                    Image(uiImage: wallpaper)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay {
                MacLockScreenLayer(lockState: lockState, userPicture: userPicture, userName: userName, isUnlocking: isUnlocking)
            }
            .clipped()
    }
}
