import LockyKit
import SwiftUI

/// Under the name of the lock screen when the iPhone is nearby and automatic unlocking is off: the
/// Unlock button, which does exactly what the button of the iPhone does. The states are written
/// in the capsule itself, readable on any wallpaper.
struct LockScreenPromptView: View {
    enum Mode: Equatable {
        /// Offer the Unlock button.
        case button
        /// Waiting for the iPhone (Face ID, notification).
        case waitingForPhone
        /// Only the Apple Watch can unlock.
        case watchOnly
    }

    let deviceName: String
    let mode: Mode
    let state: LockScreenPromptState
    let onUnlock: () -> Void

    var body: some View {
        Group {
            switch mode {
            case .button:
                // Drawn by hand: the panel never becomes key (the keyboard stays on the lock
                // screen), and system buttons and glass look disabled in an inactive window.
                Button(action: onUnlock) {
                    Label {
                        Text("Unlock")
                    } icon: {
                        Image(.lockyGlyph)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                    }
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.2, green: 0.66, blue: 1.0), Color(red: 0.09, green: 0.47, blue: 0.92)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        in: .capsule
                    )
                    .overlay(Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 1))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            case .waitingForPhone:
                StatusCapsule {
                    ProgressView()
                        .controlSize(.small)
                    Text("Confirm on \(deviceName)")
                }
            case .watchOnly:
                StatusCapsule {
                    Image(systemName: "applewatch")
                    Text("Unlock from your Apple Watch")
                }
            }
        }
        .opacity(state.isDismissed ? 0 : 1)
        .offset(y: state.isDismissed ? 6 : 0)
        .animation(.easeIn(duration: 0.18), value: state.isDismissed)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 4)
        .environment(\.colorScheme, .dark)
        .animation(.smooth, value: mode)
    }
}

/// A state written on a dark capsule, readable on any wallpaper.
private struct StatusCapsule<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        HStack(spacing: 8) {
            content
        }
        .font(.callout.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(.black.opacity(0.55), in: .capsule)
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 1))
    }
}
