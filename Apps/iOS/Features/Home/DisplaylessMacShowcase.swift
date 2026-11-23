import LockyKit
import SwiftUI

/// A Mac without a display (Mac mini, Mac Studio, Mac Pro) on the desk, under an Apple Pro Display
/// XDR that shows its wallpaper and its lock screen. The display is handled like on its real Pro
/// Stand (see ``ProDisplayXDR``) and stays the way it was left.
struct DisplaylessMacShowcase: View {
    let frame: MacFrame
    let family: MacFamily
    var wallpaper: UIImage?
    let lockState: LockState
    var isConnected: Bool = true
    var userPicture: Data?
    var userName: String?
    var isUnlocking: Bool = false

    @AppStorage("xdrPose") private var pose: ProDisplayXDRPose = .init()

    var body: some View {
        ProDisplayXDR(pose: $pose, accessoryWidth: family.widthNextToXDR) {
            MacScreen(
                wallpaper: wallpaper,
                lockState: lockState,
                userPicture: userPicture,
                userName: userName,
                isUnlocking: isUnlocking
            )
        } accessory: {
            Image(uiImage: frame.image)
                .resizable()
                .scaledToFit()
        }
        .saturation(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.45), value: lockState)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Pro Display XDR"))
        .accessibilityAction(named: Text("Rotate the display")) {
            withAnimation(.spring(duration: 0.55, bounce: 0.18)) {
                pose.rotation = pose.isPortrait ? 0 : -90
            }
        }
        .accessibilityAction(named: Text("Put the display back")) {
            withAnimation(.spring(duration: 0.55, bounce: 0.18)) {
                pose = .init()
            }
        }
    }
}

private extension MacFamily {
    /// Its width next to the 71.8 cm of the display: Mac mini 12.7 cm, Mac Studio 19.7 cm. The Mac
    /// Pro, drawn from its side, is kept small enough to stay on the desk.
    var widthNextToXDR: CGFloat {
        switch self {
        case .macMini: 0.18
        case .macPro: 0.24
        default: 0.27
        }
    }
}
