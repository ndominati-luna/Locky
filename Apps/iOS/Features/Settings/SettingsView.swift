import LockyKit
import SwiftUI

/// Preferences of Locky.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingUnpair: Bool = false

    var body: some View {
        @Bindable var preferences = model.preferences
        Form {
            LockDistanceSection()

            Section {
                Toggle("Unlock automatically", systemImage: "wave.3.right", isOn: $preferences.unlockAutomatically)
            } footer: {
                Text("Locky will automatically enter your password to unlock your Mac when you're close to it with your iPhone.")
            }

            Section {
                Toggle(
                    String(localized: "Require \(BiometricGate.biometryName)"),
                    systemImage: "faceid",
                    isOn: $preferences.requireBiometrics
                )
            } footer: {
                Text("Locky will ask you to authenticate before unlocking your Mac from your iPhone or from the lock screen of your Mac.")
            }

            Section {
                Toggle("Unlock only from Apple Watch", systemImage: "applewatch", isOn: $preferences.unlockOnlyFromWatch)
            } footer: {
                Text("Your Mac will only be unlocked from the Locky app on your Apple Watch. Locking still works everywhere.")
            }

            Section {
                Toggle("Intruder detection", systemImage: "camera.fill", isOn: $preferences.intrusionDetection)
                if model.missingMacCameraAccess != nil {
                    MacCameraWarning()
                }
                NavigationLink {
                    IntrusionsView()
                } label: {
                    Label("Break-in reports", systemImage: "photo.stack")
                }
                .badge(model.intrusions.unseenCount)
            } footer: {
                Text("Locky on your Mac will send you a photo if someone tries to unlock it while you're not there. Photos are stored in your iCloud account.")
            }

            Section {
                Toggle("Notifications", systemImage: "bell.badge", isOn: $preferences.notificationsEnabled)
                NavigationLink {
                    SoundThemePicker(selection: $preferences.soundTheme)
                } label: {
                    LabeledContent {
                        Text(preferences.soundTheme.localizedName)
                    } label: {
                        Label("Lock sound", systemImage: "speaker.wave.2")
                    }
                }
            } footer: {
                Text("Locky will send you notifications when your Mac is locked or unlocked.")
            }

            Section {
                Toggle("Live Activity", systemImage: "platter.filled.bottom.iphone", isOn: $preferences.liveActivityEnabled)
            } footer: {
                if model.areLiveActivitiesAllowed {
                    Text("The distance to your Mac and its state on the Lock Screen and in the Dynamic Island, with the Locky button. iOS ends it after 8 hours: it starts again when you open Locky.")
                } else {
                    Text("Live Activities are turned off for Locky in the Settings app.")
                }
            }

            MacSection(isConfirmingUnpair: $isConfirmingUnpair)

            Section {
                NavigationLink {
                    AboutView()
                } label: {
                    Label("About Locky", systemImage: "info.circle")
                }
                Link(destination: SupportMail.url(macStatus: model.macStatus)) {
                    Label("Contact support", systemImage: "envelope")
                }
            }
        }
        .navigationTitle("Settings")
        .scrollContentBackground(.hidden)
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.55)
        .onChange(of: [preferences.unlockAutomatically, preferences.intrusionDetection, preferences.unlockOnlyFromWatch]) {
            model.preferencesDidChange()
        }
        .onChange(of: preferences.liveActivityEnabled) {
            model.liveActivitySettingDidChange()
        }
        .confirmationDialog(
            "Forget \(model.macName)?",
            isPresented: $isConfirmingUnpair,
            titleVisibility: .visible
        ) {
            Button("Forget this Mac", role: .destructive) {
                model.unpair()
            }
        } message: {
            Text("Locky will stop locking and unlocking this Mac. You can pair it again at any time.")
        }
    }
}

/// Lock distance, set by moving the padlock on the scale.
private struct LockDistanceSection: View {
    @Environment(AppModel.self) private var model
    @State private var isCalibrating: Bool = false

    var body: some View {
        @Bindable var preferences = model.preferences
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Lock distance", systemImage: "ruler")
                    Spacer()
                    Text(Measurement(value: preferences.lockDistance, unit: UnitLength.meters), format: .lockyDistance)
                        .monospacedDigit()
                        .foregroundStyle(.tint)
                        .contentTransition(.numericText())
                }
                DistanceGauge(
                    currentDistance: model.isConnected ? model.proximity?.distance : nil,
                    lockDistance: $preferences.lockDistance,
                    isMoving: model.isMoving,
                    family: model.macStatus?.family ?? .unknown,
                    phoneImage: model.visuals.phone,
                    onCommit: model.preferencesDidChange
                )
            }
            .padding(.vertical, 6)
            Button("Calibrate the distance", systemImage: "scope") {
                isCalibrating = true
            }
            .sheet(isPresented: $isCalibrating) {
                DistanceCalibrationView()
            }
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        let adjust: String = .init(localized: "Adjust the lock distance by moving the padlock.")
        guard model.isConnected, let distance = model.proximity?.distance else { return adjust }
        let formatted: String = Measurement(value: distance, unit: UnitLength.meters).formatted(.lockyDistance)
        return adjust + " " + String(localized: "Your iPhone is about \(formatted) from your Mac.")
    }
}

/// Information about the paired Mac and unpairing.
private struct MacSection: View {
    @Environment(AppModel.self) private var model
    @Binding var isConfirmingUnpair: Bool

    var body: some View {
        Section("Paired Mac") {
            LabeledContent("Name", value: model.macName)
            if let status = model.macStatus {
                LabeledContent("Model", value: status.productName)
                LabeledContent("macOS", value: status.systemVersion)
                LabeledContent("Unlocks by Locky", value: status.unlockCount, format: .number)
            }
            Button("Forget this Mac", systemImage: "xmark.circle", role: .destructive) {
                isConfirmingUnpair = true
            }
            // The icon takes the tint of the list, not the red of the destructive title.
            .tint(.red)
        }
    }
}
