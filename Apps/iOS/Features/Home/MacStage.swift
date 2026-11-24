import LockyKit
import SwiftUI

/// A Mac floating over its wallpaper, with its name under it. It can be pulled around and always
/// springs back to the center; a Mac without a display stands under a Pro Display XDR, a MacBook
/// folds its lid and an iMac tilts its display, all handled with their own gestures. Out of reach,
/// the Mac is left alone and faded. The home screen shows the paired Mac on it, the Mac lab any Mac
/// of the catalog.
struct MacStage: View {
    let frame: MacFrame?
    let family: MacFamily
    var wallpaper: UIImage?
    let lockState: LockState
    var isConnected: Bool = true
    var userPicture: Data?
    var userName: String?
    var isUnlocking: Bool = false
    let name: String
    /// Under the name, smaller: its model when the Mac has a name of its own.
    var detail: String?

    @State private var drag: CGSize = .zero

    var body: some View {
        let isLaptop: Bool = family.isLaptop
        let macBook: MacBookOutline? = isLaptop ? frame.flatMap { MacBookOutline.of($0) } : nil
        let iMac: IMacOutline? = family == .iMac ? frame.flatMap { IMacOutline.of($0) } : nil
        let hasOwnGestures: Bool = (frame != nil && frame?.screen == nil) || macBook != nil || iMac != nil
        VStack(spacing: 14) {
            Group {
                if let frame, let macBook {
                    MacBookShowcase(
                        frame: frame,
                        outline: macBook,
                        wallpaper: wallpaper,
                        lockState: lockState,
                        isConnected: isConnected,
                        userPicture: userPicture,
                        userName: userName,
                        isUnlocking: isUnlocking,
                        pulled: pulled
                    )
                } else if let frame, let iMac {
                    IMacShowcase(
                        frame: frame,
                        outline: iMac,
                        wallpaper: wallpaper,
                        lockState: lockState,
                        isConnected: isConnected,
                        userPicture: userPicture,
                        userName: userName,
                        isUnlocking: isUnlocking,
                        pulled: pulled
                    )
                } else if let frame, frame.screen == nil {
                    // No display of its own: under a Pro Display XDR.
                    DisplaylessMacShowcase(
                        frame: frame,
                        family: family,
                        wallpaper: wallpaper,
                        lockState: lockState,
                        isConnected: isConnected,
                        userPicture: userPicture,
                        userName: userName,
                        isUnlocking: isUnlocking,
                        pulled: pulled
                    )
                } else {
                    MacDeviceImage(
                        frame: frame,
                        family: family,
                        wallpaper: wallpaper,
                        lockState: lockState,
                        isConnected: isConnected,
                        userPicture: userPicture,
                        userName: userName,
                        isUnlocking: isUnlocking
                    )
                }
            }
            .foregroundStyle(.primary)
            // Grows with the large screen of an unfolded iPhone Duo held upright.
            .frame(maxWidth: 560, maxHeight: 380)
            .shadow(color: .black.opacity(0.45), radius: 24, y: 14 + drag.height * 0.1)
            .offset(drag)
            .rotation3DEffect(.degrees(Double(drag.width) * 0.08), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(Double(-drag.height) * 0.08), axis: (x: 1, y: 0, z: 0))
            // The fingers belong to the display or the lid, which pull the Mac themselves.
            .gesture(rubberBand, including: hasOwnGestures ? .subviews : .all)
            .disabled(!isConnected)
            // Over its name too.
            .zIndex(1)
            // Out of reach in the middle of a pull: the gesture is cancelled, the Mac comes back.
            .onChange(of: isConnected) {
                springBack()
            }

            VStack(spacing: 4) {
                Text(name)
                    .font(.title2.bold())
                if let detail, detail != name {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .fadedWhileOutOfReach(!isConnected)
    }

    /// One finger on the Mac of a showcase pulls it like anywhere else.
    private func pulled(_ translation: CGSize?) {
        if let translation {
            drag = resisted(translation)
        } else {
            springBack()
        }
    }

    /// The further you pull, the harder it resists; released, it bounces back to the center.
    private var rubberBand: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                drag = resisted(value.translation)
            }
            .onEnded { _ in
                springBack()
            }
    }

    private func resisted(_ translation: CGSize) -> CGSize {
        .init(width: resist(translation.width), height: resist(translation.height))
    }

    private func resist(_ translation: CGFloat) -> CGFloat {
        let limit: CGFloat = 90
        return limit * translation / (abs(translation) + limit)
    }

    private func springBack() {
        withAnimation(.spring(duration: 0.6, bounce: 0.55)) { drag = .zero }
    }
}
