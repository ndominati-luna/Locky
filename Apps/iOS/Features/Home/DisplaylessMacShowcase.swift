import LockyKit
import SwiftUI

/// A Mac without a display (Mac mini, Mac Studio, Mac Pro) on the desk, under an Apple Pro Display
/// XDR that shows its wallpaper and its lock screen, linked to it by its cable, a Magic Keyboard and
/// a Magic Trackpad in front. The display is handled like on its real Pro Stand (see
/// ``ProDisplayXDR``); two fingers set down on the Mac slide it along the desk, the cable following.
/// Both stay the way they were left. Two fingers spreading on the keyboard bring the one with the
/// numeric keypad, closing on it the compact one; one finger on the trackpad shows the cursor on
/// the screen, which follows it until it lifts.
struct DisplaylessMacShowcase: View {
    let frame: MacFrame
    let family: MacFamily
    var wallpaper: UIImage?
    let lockState: LockState
    var isConnected: Bool = true
    var userPicture: Data?
    var userName: String?
    var isUnlocking: Bool = false
    /// One finger off the display and off the trackpad: how far it pulled the whole desk, then
    /// `nil` once let go.
    let pulled: (CGSize?) -> Void

    @AppStorage("xdrPose") private var pose: ProDisplayXDRPose = .init()
    /// Where the Mac was slid along the desk, in widths of the display.
    @AppStorage("macDeskOffset") private var deskOffset: Double = 0
    /// The keyboard on the desk, with its numeric keypad or not, as two fingers left it.
    @AppStorage("deskKeyboard") private var storedKeyboard: DeskKeyboard = .compact
    /// State, which animates, unlike the stored value.
    @State private var restingKeyboard: DeskKeyboard?
    /// How many times wider the fingers spread the keyboard, while they do.
    @State private var keyboardStretch: CGFloat = 1
    @State private var haptics: HingeHaptics = .init()
    @State private var showsCursor: Bool = false
    @State private var cursor: CGPoint = .init(x: 0.5, y: 0.5)
    @State private var cursorStart: CGPoint = .init(x: 0.5, y: 0.5)
    /// The trackpad on screen, as wide as the last time it was found.
    @State private var trackpadWidth: CGFloat = 1

    /// The keyboard and the trackpad, in front of the foot of the display.
    private static let accessoriesBack: CGFloat = 20
    /// The silver aluminium of the keyboard and the trackpad sold on their own.
    private static let silver: Color = .init(.sRGB, red: 0.86, green: 0.865, blue: 0.875)

    var body: some View {
        ProDisplayXDR(
            pose: $pose,
            accessoryWidth: family.widthNextToXDR,
            accessoryAspectRatio: frame.image.size.width / max(frame.image.size.height, 1),
            accessoryOffset: $deskOffset,
            hasCable: true,
            frontDepth: DeskAccessories.front(back: Self.accessoriesBack),
            frontArea: { camera in
                DeskAccessories.keyboardFrame(camera: camera, back: Self.accessoriesBack, width: keyboard.width)
            },
            frontPinchChanged: { keyboardStretch = $0 },
            frontPinchEnded: settleKeyboard,
            frontPointerArea: { camera in
                let trackpad: CGRect = DeskAccessories.trackpadFrame(camera: camera, back: Self.accessoriesBack, keyboardWidth: keyboard.width)
                trackpadWidth = max(trackpad.width, 1)
                return trackpad
            },
            frontPointerMoved: moveCursor,
            pulled: pulled
        ) {
            MacScreen(
                wallpaper: wallpaper,
                lockState: lockState,
                userPicture: userPicture,
                userName: userName,
                isUnlocking: isUnlocking
            )
            .overlay {
                if showsCursor {
                    MacCursor(position: cursor)
                        .transition(.opacity)
                }
            }
        } accessory: {
            Image(uiImage: frame.image)
                .resizable()
                .scaledToFit()
        } front: { camera in
            DeskAccessories(
                camera: camera,
                back: Self.accessoriesBack,
                keyboard: keyboard,
                colour: "Silver",
                aluminium: Self.silver,
                keyboardWidth: keyboard.width(stretchedBy: keyboardStretch)
            )
        }
        .saturation(isConnected ? 1 : 0.3)
        .animation(.easeInOut(duration: 0.45), value: lockState)
        // Out of reach, like the rest of the Mac, it is left alone.
        .disabled(!isConnected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Pro Display XDR"))
        .accessibilityActions {
            if isConnected {
                Button("Rotate the display") {
                    withAnimation(.spring(duration: 0.55, bounce: 0.18)) {
                        pose.rotation = pose.isPortrait ? 0 : -90
                    }
                }
                Button("Put the display back") {
                    withAnimation(.spring(duration: 0.55, bounce: 0.18)) {
                        pose = .init()
                        deskOffset = 0
                    }
                }
            }
        }
    }
}

extension DisplaylessMacShowcase {
    private var keyboard: DeskKeyboard {
        restingKeyboard ?? storedKeyboard
    }

    /// One finger on the trackpad: the cursor shows and moves as the finger does, across the
    /// trackpad a little more than the width of the screen; it goes once the finger lifts.
    private func moveCursor(_ translation: CGSize?) {
        guard let translation else {
            withAnimation(.easeIn(duration: 0.2)) { showsCursor = false }
            return
        }
        if !showsCursor {
            cursorStart = cursor
            withAnimation(.easeOut(duration: 0.12)) { showsCursor = true }
        }
        // The display is 16 by 9.
        cursor = .init(
            x: min(max(cursorStart.x + translation.width / trackpadWidth * 1.3, 0), 0.98),
            y: min(max(cursorStart.y + translation.height / trackpadWidth * 1.3 * 16 / 9, 0), 0.97)
        )
    }

    /// Spread enough, the keyboard with the numeric keypad; closed enough, the compact one.
    private func settleKeyboard(_ ratio: CGFloat) {
        let settled: DeskKeyboard = keyboard.settled(afterStretching: ratio)
        if settled != keyboard {
            haptics.knock(isDeep: settled == .compact)
        }
        withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
            restingKeyboard = settled
            keyboardStretch = 1
        }
        storedKeyboard = settled
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
