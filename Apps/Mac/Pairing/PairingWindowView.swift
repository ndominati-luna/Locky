import LockyKit
import SwiftUI

/// Pairing assistant.
struct PairingWindowView: View {
    @Environment(MacAppModel.self) private var model

    var body: some View {
        VStack(spacing: 24) {
            content
                .id(stepIdentity)
                .transition(.blurReplace)
        }
        .padding(36)
        .frame(width: 520, height: 540)
        .animation(.smooth, value: stepIdentity)
        .tint(Color.brandArt)
        // Same brand background as the iPhone: light or night blue depending on the appearance.
        .background(BrandBackground())
    }

    private var stepIdentity: String {
        String(describing: model.session.pairingStep) + String(model.isPaired) + String(describing: model.setupStep)
    }

    @ViewBuilder
    private var content: some View {
        switch model.session.pairingStep {
        case .idle:
            if model.isPaired {
                SetupStep(step: model.setupStep)
            } else {
                IntroStep()
            }
        case .searching:
            StepHeader(
                symbol: "iphone.radiowaves.left.and.right",
                title: "Looking for Locky iPhones…",
                message: "Open Locky on your iPhone and keep it close to your Mac.",
                animated: true
            )
            ProgressView()
            CancelPairingButton()
        case let .deviceFound(name, modelIdentifier):
            DeviceFoundStep(name: name, modelIdentifier: modelIdentifier)
        case let .confirmCode(code, deviceName, isConfirmedOnMac, isConfirmedOnPhone):
            StepHeader(
                symbol: "number.square",
                title: "Check the code",
                message: "Make sure \(deviceName) displays the same code, then confirm on both devices.",
                animated: false
            )
            Text("\(code.prefix(3)) \(code.suffix(3))")
                .font(.system(.largeTitle, design: .monospaced).bold())
                .foregroundStyle(Color.brandArt)
                .tracking(6)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
            Label(
                isConfirmedOnPhone ? "Confirmed on the iPhone" : "Waiting for the confirmation on the iPhone…",
                systemImage: isConfirmedOnPhone ? "checkmark.circle.fill" : "iphone"
            )
            .foregroundStyle(isConfirmedOnPhone ? .green : .secondary)
            HStack(spacing: 14) {
                Button("Not the same code", role: .cancel, action: model.session.cancelPairing)
                    .buttonStyle(.brandOutlineCapsule)
                Button(isConfirmedOnMac ? "Confirmed" : "The codes match", action: model.session.confirmCodeOnMac)
                    .buttonStyle(.brandCapsule)
                    .frame(width: 200)
                    .keyboardShortcut(.defaultAction)
                    .disabled(isConfirmedOnMac)
            }
        case let .password(deviceName):
            PasswordStep(deviceName: deviceName)
        case .calibrating:
            StepHeader(
                symbol: "iphone.gen3.radiowaves.left.and.right",
                title: "Calibrating",
                message: "Put your iPhone about 1 m from your Mac, then 2 m, confirming each time on your iPhone.\nPlease don't touch it during the measures.",
                animated: true
            )
            ProgressView()
        case .completed:
            SetupStep(step: model.setupStep)
        case let .failed(message):
            StepHeader(symbol: "exclamationmark.triangle", title: "Pairing failed", message: LocalizedStringKey(message), animated: false)
            Button("Try again", action: model.startPairing)
                .buttonStyle(.brandCapsule)
                .frame(width: 200)
        }
    }
}

/// Once paired: permissions, then the guided first try.
private struct SetupStep: View {
    let step: MacSetupStep

    var body: some View {
        switch step {
        case .permissions: PermissionsStep()
        case .firstTry: FirstTryStep()
        case .magic: MagicStep()
        }
    }
}

/// Download the iPhone app and start.
private struct IntroStep: View {
    @Environment(MacAppModel.self) private var model

    var body: some View {
        StepHeader(
            symbol: "macbook.and.iphone",
            title: "Welcome to Locky",
            message: "Locky locks your Mac when you walk away with your iPhone and unlocks it when you come back.",
            animated: false
        )
        HStack(spacing: 20) {
            QRCodeView(url: IPhoneAppLink.download)
                .frame(width: 110, height: 110)
                .padding(8)
                .background(.white, in: .rect(cornerRadius: 12))
            Text("Scan this code with your iPhone to install Locky, then open it.")
                .foregroundStyle(.secondary)
        }
        Button("Connect to my iPhone", action: model.startPairing)
            .buttonStyle(.brandCapsule)
            .frame(width: 260)
            .keyboardShortcut(.defaultAction)
    }
}

/// An iPhone answered.
private struct DeviceFoundStep: View {
    @Environment(MacAppModel.self) private var model
    let name: String
    let modelIdentifier: String

    var body: some View {
        Group {
            if let image = DeviceIcon.image(forModelIdentifier: modelIdentifier) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "iphone")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.brandArt)
            }
        }
        .frame(height: 140)
        Text(name)
            .font(.title.bold())
        Text("Is this your iPhone?")
            .foregroundStyle(.secondary)
        HStack(spacing: 14) {
            Button("Not this one", action: model.session.rejectFoundDevice)
                .buttonStyle(.brandOutlineCapsule)
            Button("Pair", action: model.session.acceptFoundDevice)
                .buttonStyle(.brandCapsule)
                .frame(width: 160)
                .keyboardShortcut(.defaultAction)
        }
    }
}

/// Session password, verified then stored on the iPhone.
private struct PasswordStep: View {
    @Environment(MacAppModel.self) private var model
    let deviceName: String
    @State private var password: String = ""
    @State private var isVerifying: Bool = false
    @State private var isWrong: Bool = false

    var body: some View {
        StepHeader(
            symbol: "key.horizontal",
            title: "Your session password",
            message: "Locky types it on the lock screen to unlock your Mac. It is checked here, then kept only in the keychain of \(deviceName).",
            animated: false
        )
        SecureField("Password of \(NSFullUserName())", text: $password)
            .textFieldStyle(.roundedBorder)
            .frame(width: 280)
            .onSubmit(submit)
            .disabled(isVerifying)
        if isWrong {
            Text("This password is not the one of your session.")
                .font(.callout)
                .foregroundStyle(.red)
        }
        HStack(spacing: 14) {
            CancelPairingButton()
            Button(action: submit) {
                if isVerifying {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Continue")
                }
            }
            .buttonStyle(.brandCapsule)
            .frame(width: 160)
            .keyboardShortcut(.defaultAction)
            .disabled(password.isEmpty || isVerifying)
        }
    }

    private func submit() {
        guard !password.isEmpty else { return }
        isVerifying = true
        isWrong = false
        Task {
            let success: Bool = await model.session.submitPassword(password)
            isVerifying = false
            isWrong = !success
            if success {
                password = ""
            }
        }
    }
}

/// Permissions checklist shown at the end of the pairing, then the offer to try Locky.
private struct PermissionsStep: View {
    @Environment(MacAppModel.self) private var model
    @State private var isCameraAllowed: Bool = IntruderCamera.isAuthorized

    var body: some View {
        StepHeader(
            symbol: "checkmark.seal.fill",
            title: "You're all set",
            message: "Locky will be available in your Mac's top bar. A few permissions make it work at its best:",
            animated: false
        )
        VStack(alignment: .leading, spacing: 12) {
            PermissionRow(
                title: "Accessibility",
                detail: "Required to type your password on the lock screen.",
                isGranted: model.isAccessibilityGranted,
                action: model.requestAccessibility
            )
            PermissionRow(
                title: "Camera",
                detail: "Optional: photos of intruders.",
                isGranted: isCameraAllowed
            ) {
                Task {
                    isCameraAllowed = await IntruderCamera.requestAccess()
                    model.refreshCameraAccess()
                }
            }
            // Only when the wallpaper sits in a folder macOS protects (Documents…).
            if model.wallpaperAccess != .notNeeded {
                PermissionRow(
                    title: "Wallpaper",
                    detail: "Optional: your wallpaper is in a protected folder. Locky shows it on your iPhone and in its animations.",
                    isGranted: model.wallpaperAccess == .granted,
                    action: model.requestWallpaperAccess
                )
            }
            Toggle("Open Locky at login", isOn: Binding(get: { model.isLaunchAtLoginEnabled }, set: model.setLaunchAtLogin))
        }
        .frame(maxWidth: 400)
        VStack(spacing: 10) {
            // The first try is mandatory: no way to postpone it.
            Button("Try it now", action: model.startFirstTry)
                .buttonStyle(.brandCapsule)
                .frame(width: 200)
                .keyboardShortcut(.defaultAction)
            Text(model.isAccessibilityGranted ? "Walk away with your iPhone, then come back." : "Allow Accessibility first: Locky types your password to unlock your Mac.")
                .font(.caption)
                .foregroundStyle(Color.secondary)
                .multilineTextAlignment(.center)
        }
        .onAppear {
            #if DEBUG
            guard !MacDemo.isEnabled else { return }
            #endif
            if !model.isLaunchAtLoginEnabled {
                model.setLaunchAtLogin(true)
            }
        }
    }
}

private struct PermissionRow: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let isGranted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isGranted ? .green : .secondary)
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isGranted {
                Button("Allow…", action: action)
            }
        }
    }
}

private struct CancelPairingButton: View {
    @Environment(MacAppModel.self) private var model

    var body: some View {
        Button("Cancel", role: .cancel, action: model.session.cancelPairing)
            .buttonStyle(.brandOutlineCapsule)
    }
}
