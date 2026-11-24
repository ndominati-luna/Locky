import LockyKit
import SwiftUI

/// The paired Mac: its exact product image with its wallpaper on screen, otherwise the SF Symbol of
/// its family. When the Mac is locked, its screen shows an imitation of the macOS lock screen (user
/// picture and password field), exactly centered in the display.
struct MacDeviceImage: View {
    /// The Mac from the catalog of the app (screen transparent), or a ready made rendition.
    let frame: MacFrame?
    let family: MacFamily
    /// Drawn in the screen of a catalog ``frame``, as the original Locky did.
    var wallpaper: UIImage?
    var lockState: LockState = .unknown
    var isConnected: Bool = true
    var userPicture: Data?
    var userName: String?
    /// Locky is typing the password on the Mac: dots appear in the password field.
    var isUnlocking: Bool = false

    var body: some View {
        Group {
            if let frame {
                Image(uiImage: frame.image)
                    .resizable()
                    .scaledToFit()
                    // Catalog image: the wallpaper and the lock screen go behind its transparent
                    // screen, the bezel, notch and rounded corners stay drawn over them.
                    .background {
                        if !frame.hasWallpaper, let screen = frame.screen {
                            ScreenRectLayout(rect: screen, outset: 1) {
                                MacScreen(
                                    wallpaper: wallpaper,
                                    lockState: lockState,
                                    userPicture: userPicture,
                                    userName: userName,
                                    isUnlocking: isUnlocking
                                )
                            }
                        }
                    }
                    // Rendition: the wallpaper is in the image, only the lock screen goes over it.
                    .overlay {
                        if frame.hasWallpaper, let screen = frame.screen {
                            ScreenRectLayout(rect: screen) {
                                MacLockScreenLayer(
                                    lockState: lockState,
                                    userPicture: userPicture,
                                    userName: userName,
                                    isUnlocking: isUnlocking
                                )
                            }
                        }
                    }
                    .overlay {
                        if lockState == .locked, frame.screen == nil {
                            PadlockBadge()
                        }
                    }
            } else {
                Image(systemName: family.systemImage)
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.thin)
                    .overlay {
                        if lockState == .locked {
                            PadlockBadge()
                        }
                    }
            }
        }
        .saturation(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.45), value: lockState)
        .accessibilityHidden(true)
    }
}

/// Lock badge for Macs without a built-in display.
private struct PadlockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.title)
            .foregroundStyle(.white)
            .padding(10)
            .background(.black.opacity(0.45), in: .circle)
            .transition(.scale.combined(with: .opacity))
    }
}
