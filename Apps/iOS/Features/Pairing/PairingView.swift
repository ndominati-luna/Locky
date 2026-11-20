import LockyKit
import SwiftUI

/// Pairing with a Mac, driven by the Mac app, on the Locky blue of the original setup screens.
struct PairingView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack {
            BrandBackground()
            PairingStepContent(step: model.session.pairingStep)
                .id(stepIdentity)
                .transition(.blurReplace)
        }
        // Illustrations in Locky blue (Light Mode) or white (Dark Mode); texts use the label colors.
        .foregroundStyle(Color.brandArt)
        .animation(.smooth, value: stepIdentity)
        .safeAreaInset(edge: .bottom) {
            SecondPageOnly {
                if model.session.connection == .bluetoothOff || model.session.connection == .unauthorized {
                    Label("Turn on Bluetooth and allow Locky to use it.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .padding()
                }
            }
        }
    }

    private var stepIdentity: String {
        String(describing: model.session.pairingStep)
    }
}

/// Content of a pairing step.
private struct PairingStepContent: View {
    @Environment(AppModel.self) private var model
    let step: PairingStep

    var body: some View {
        switch step {
        case .waitingForMac:
            StepLayout {
                WaitingForMacIllustration()
                    .frame(height: 170)
            } details: {
                PairingMessage(
                    title: "Setup",
                    message: "Open Locky on your Mac and choose “Connect to an iPhone”. Put your iPhone close to your Mac, and check that Bluetooth is activated on both devices."
                )
                ShareLink(item: MacAppLink.download) {
                    Label("Get the link for Mac", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.brandOutlineCapsule)
            }
        case let .macFound(name, family):
            StepLayout {
                Image(systemName: family.systemImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 110)
                    .symbolEffect(.bounce, options: .nonRepeating)
            } details: {
                PairingMessage(title: "\(name) found your iPhone", message: "Click “Pair” on your Mac to continue.")
            }
        case let .confirmCode(code, macName):
            CodeConfirmation(code: code, macName: macName)
        case let .waitingForPassword(macName):
            StepLayout {
                Image(systemName: "key.horizontal.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 90)
                    .symbolEffect(.wiggle, options: .repeat(.periodic(delay: 1.5)))
            } details: {
                PairingMessage(
                    title: "Type your password on \(macName)",
                    message: "Locky needs your macOS session password to unlock your Mac. It is verified on your Mac, then stored only in the keychain of this iPhone."
                )
            }
        case .calibrating(.near):
            StepLayout {
                SignalIllustration()
                    .frame(height: 170)
            } details: {
                PairingMessage(
                    // A no-break space keeps "1 m" together.
                    title: "Stand 1\u{00A0}m from your Mac",
                    message: "Stand about 1 m from your Mac (a big step), your back to it, your iPhone in your hand in front of you: you are between them, as when you walk away. Confirm, then stay still. Locky measures the signal there, then at 2 m, to know the distance."
                )
                Button("Confirm") {
                    model.session.startPairingCalibration()
                }
                .buttonStyle(.brandCapsule)
            }
        case .calibrating(.far):
            StepLayout {
                SignalIllustration()
                    .frame(height: 170)
            } details: {
                PairingMessage(
                    title: "Step back to 2\u{00A0}m",
                    message: "Now step back to about 2 m from your Mac (two big steps), still with your back to it and your iPhone in front of you, then confirm."
                )
                Button("Confirm") {
                    model.session.startPairingCalibration()
                }
                .buttonStyle(.brandCapsule)
            }
        case .measuring:
            StepLayout {
                SignalIllustration()
                    .frame(height: 170)
            } details: {
                PairingMessage(
                    title: "The magic will happen soon",
                    message: "Don't move for a few seconds."
                )
                ProgressView()
                    .tint(Color.brandArt)
            }
        case .completed:
            StepLayout {
                LockyAssemblyIllustration()
                    .frame(height: 200)
            } details: {
                PairingMessage(
                    title: "The magic happened!",
                    message: "Walk away with your iPhone: your Mac will lock. Come back: it will unlock."
                )
            }
        case let .failed(message):
            StepLayout {
                Image(systemName: "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 90)
            } details: {
                PairingMessage(title: "Pairing failed", message: LocalizedStringKey(message))
                Button("Try again") {
                    model.session.cancelPairing()
                }
                .buttonStyle(.brandCapsule)
            }
        }
    }
}

/// The Mac outline with radio waves, waiting for the Mac to show up.
private struct WaitingForMacIllustration: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.largeTitle)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating)
            MacOutline()
        }
        .accessibilityHidden(true)
    }
}

/// Verification code the user compares with the Mac.
private struct CodeConfirmation: View {
    @Environment(AppModel.self) private var model
    let code: String
    let macName: String

    var body: some View {
        StepLayout {
            Image(systemName: "checkmark.shield.fill")
                .resizable()
                .scaledToFit()
                .frame(height: 90)
        } details: {
            PairingMessage(title: "Check the code", message: "Make sure \(macName) displays the same code.")
            Text(code.chunked)
                .font(.system(.largeTitle, design: .monospaced).bold())
                .tracking(4)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 18))
                .accessibilityLabel(Text(code.map(String.init).joined(separator: " ")))
            Button("The codes match") {
                model.session.confirmPairingCode()
            }
            .buttonStyle(.brandCapsule)
            Button("Cancel", role: .cancel) {
                model.session.cancelPairing()
            }
            .foregroundStyle(Color.brandArt)
        }
    }
}

/// Title and explanation of a step.
private struct PairingMessage: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            // Label colors, not the hierarchical levels of the brand color set on the screen.
            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color.primary)
            Text(message)
                .foregroundStyle(Color.secondary)
        }
        .multilineTextAlignment(.center)
    }
}

extension String {
    /// "123456" → "123 456".
    fileprivate var chunked: String {
        guard count == 6 else { return self }
        return "\(prefix(3)) \(suffix(3))"
    }
}
