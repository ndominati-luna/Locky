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
                            ScreenRectLayout(rect: screen) {
                                screenContent
                            }
                        }
                    }
                    // Rendition: the wallpaper is in the image, only the lock screen goes over it.
                    .overlay {
                        if frame.hasWallpaper, let screen = frame.screen {
                            ScreenRectLayout(rect: screen) {
                                lockScreen
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

    /// The display of the Mac: its wallpaper (black without one), then the lock screen. The black
    /// fill sets the size: a wallpaper scaled to fill would otherwise widen the screen past the bezel.
    private var screenContent: some View {
        Color.black
            .overlay {
                if let wallpaper {
                    Image(uiImage: wallpaper)
                        .resizable()
                        .scaledToFill()
                }
            }
            .overlay {
                lockScreen
            }
            .clipped()
    }

    @ViewBuilder
    private var lockScreen: some View {
        if lockState == .locked {
            MacLockScreenView(userPicture: userPicture, userName: userName, isUnlocking: isUnlocking)
                // Fades in when locking; zooms out of the way when unlocking, like macOS.
                .transition(.asymmetric(insertion: .opacity, removal: .opacity.combined(with: .scale(scale: 1.06))))
        }
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
