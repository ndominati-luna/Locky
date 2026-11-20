import LockyKit
import SwiftUI

/// Guided first try after the pairing, on the Locky blue of the setup screens: finish on the Mac,
/// walk away until it locks, come back until it unlocks, then celebrate. The Mac pairing window
/// follows the same steps.
struct FirstTryView: View {
    @Environment(AppModel.self) private var model
    let phase: SetupPhase

    var body: some View {
        ZStack {
            BrandBackground()
            FirstTryPhaseContent(phase: phase)
                .id(phase)
                .transition(.blurReplace)
        }
        // Illustrations in Locky blue (Light Mode) or white (Dark Mode); texts use the label colors.
        .foregroundStyle(Color.brandArt)
        .animation(.smooth, value: phase)
        .safeAreaInset(edge: .bottom) {
            // The first try is mandatory: the only way out is its success.
            SecondPageOnly {
                if phase == .magic {
                    Button("Done", action: model.finishSetup)
                        .buttonStyle(.brandCapsule)
                        .frame(maxWidth: 420)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 12)
                }
            }
        }
        .sensoryFeedback(.success, trigger: phase == .magic) { _, isMagic in isMagic }
        .sensoryFeedback(.impact, trigger: phase == .comeBack) { _, isLocked in isLocked }
    }
}

/// Illustration, texts and live distance of a phase.
private struct FirstTryPhaseContent: View {
    @Environment(AppModel.self) private var model
    let phase: SetupPhase

    var body: some View {
        switch phase {
        case .waitingForMac:
            StepLayout(columnPadding: Self.columnPadding) {
                SetupMacImage(lockState: .unlocked)
            } details: {
                SetupMessage(
                    title: "Finish on your Mac",
                    message: "Your iPhone is paired with \(model.macName). Allow Locky on your Mac, then click “Try it now”: walk away, come back, and watch the magic happen."
                )
            }
        case .walkAway:
            StepLayout(columnPadding: Self.columnPadding) {
                WalkAwayIllustration()
                    .frame(height: 120)
            } details: {
                SetupMessage(
                    title: "Walk away from your Mac",
                    message: "Take your iPhone with you, in your hand or in your pocket. Beyond \(Measurement(value: model.preferences.lockDistance, unit: UnitLength.meters), format: .lockyDistance), Locky locks your Mac."
                )
                SetupDistanceCard()
            }
        case .comeBack:
            StepLayout(columnPadding: Self.columnPadding) {
                SetupMacImage(lockState: .locked)
            } details: {
                SetupMessage(
                    title: "Your Mac is locked",
                    message: "Now come back to it: Locky unlocks your Mac as you get closer."
                )
                SetupDistanceCard()
            }
        case .magic:
            StepLayout(columnPadding: Self.columnPadding) {
                LockyAssemblyIllustration()
                    .frame(height: 200)
            } details: {
                SetupMessage(
                    title: "The magic happened!",
                    message: "Locky locked your Mac when you walked away and unlocked it when you came back. It now works on its own, even with your iPhone in your pocket."
                )
            }
        }
    }

    private static let columnPadding: EdgeInsets = .init(top: 56, leading: 32, bottom: 32, trailing: 32)
}

/// The paired Mac, showing its lock screen once locked (with the typing dots while unlocking).
private struct SetupMacImage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.screenFold) private var fold
    let lockState: LockState

    var body: some View {
        MacDeviceImage(
            frame: model.macFrame,
            family: model.macStatus?.family ?? .unknown,
            wallpaper: model.visuals.wallpaperImage,
            lockState: lockState == .locked ? model.lockState : .unlocked,
            isConnected: model.isConnected,
            userPicture: model.visuals.userPicture,
            userName: model.macStatus?.userName,
            isUnlocking: model.isUnlocking
        )
        .foregroundStyle(Color.primary)
        .frame(height: fold == nil ? 190 : 250)
        .animation(.easeInOut(duration: 0.45), value: model.lockState)
    }
}

/// The distance gauge: this iPhone moving away from the Mac towards the padlock (lock distance).
private struct SetupDistanceCard: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var preferences = model.preferences
        VStack(spacing: 12) {
            DistanceGauge(
                currentDistance: model.isConnected ? model.proximity?.distance : nil,
                lockDistance: $preferences.lockDistance,
                lockState: model.lockState,
                isMoving: model.isMoving,
                family: model.macStatus?.family ?? .unknown,
                phoneImage: model.visuals.phone,
                onCommit: model.preferencesDidChange
            )
            Group {
                if model.isConnected, let distance = model.proximity?.distance {
                    Text("Your iPhone is about \(Measurement(value: distance, unit: UnitLength.meters), format: .lockyDistance) from your Mac.")
                        .contentTransition(.numericText())
                        .animation(.smooth, value: distance)
                } else {
                    Text("Waiting for your Mac…")
                }
            }
            .font(.footnote)
            .foregroundStyle(Color.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(20)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }
}

/// Title and explanation of a phase.
private struct SetupMessage: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.title, design: .rounded, weight: .bold))
                .foregroundStyle(Color.primary)
            Text(message)
                .foregroundStyle(Color.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .multilineTextAlignment(.center)
    }
}
