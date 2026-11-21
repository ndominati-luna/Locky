import LockyKit
import SwiftUI

/// Preferences of Locky.
struct SettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var isConfirmingUnpair: Bool = false

    var body: some View {
        @Bindable var preferences = model.preferences
        Form {
            // What the Mac applies, changed even out of reach.
            AutoLockSection()

            LockDistanceSection()

            IntrusionSection()

            LockAnimationSection()

            Section {
                Toggle("Unlock automatically", systemImage: "wave.3.right", isOn: $preferences.unlockAutomatically)
            } header: {
                Text("Unlocking")
            } footer: {
                Text("Locky will automatically enter your password to unlock your Mac when you're close to it with your iPhone.")
            }

            Section {
                Toggle(
                    String(localized: "Require \(BiometricGate.biometryName)"),
                    systemImage: BiometricGate.biometrySymbol,
                    isOn: $preferences.requireBiometrics
                )
            } footer: {
                if let biometry = BiometricGate.biometry {
                    Text("Locky will ask for \(biometry.name) before unlocking your Mac from your iPhone or from the lock screen of your Mac.")
                } else {
                    Text("Locky will ask you to authenticate before unlocking your Mac from your iPhone or from the lock screen of your Mac.")
                }
            }

            Section {
                Toggle("Unlock only from Apple Watch", systemImage: "applewatch", isOn: $preferences.unlockOnlyFromWatch)
            } footer: {
                Text("Your Mac will only be unlocked from the Locky app on your Apple Watch. Locking still works everywhere.")
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

            MacAppSection()

            Section {
                Link(destination: SupportMail.url(macStatus: model.macStatus)) {
                    Label {
                        Text("Contact support")
                    } icon: {
                        Image(systemName: "envelope")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                // A link draws its title in the tint: primary like the other rows, the icon stays blue.
                .tint(.primary)
            }
        }
        .navigationTitle("Settings")
        .task {
            await model.loadMacReleases()
        }
        .scrollContentBackground(.hidden)
        // Faded like the main screen while the Mac is out of reach.
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.55, isFaded: !model.isConnected)
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

/// "Locky activated" on the Mac: locking when the iPhone walks away. Set on the Mac too; changed
/// here in reach, or out of reach with a Mac that reads its settings in iCloud.
private struct AutoLockSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Section {
            Toggle(
                "Lock automatically",
                systemImage: "figure.walk.departure",
                isOn: .init(
                    get: { model.macStatus?.isAutoLockEnabled ?? true },
                    set: { model.setMacAutoLock($0) }
                )
            )
            .disabled(!model.canChangeMacSettings || model.macStatus == nil)
        } header: {
            Text("Your Mac")
        } footer: {
            if model.canChangeMacSettings {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Locky locks your Mac when you walk away with your iPhone. Same as “Locky activated” in the Locky menu on your Mac.")
                    OutOfReachNote()
                }
            } else {
                Text("Your Mac must be in reach to change it.")
            }
        }
    }
}

/// Photos of the people trying to unlock the Mac while the iPhone is away: precisely when the Mac
/// is out of reach, hence changed through iCloud then.
private struct IntrusionSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var preferences = model.preferences
        Section {
            Toggle("Intruder detection", systemImage: "camera.fill", isOn: $preferences.intrusionDetection)
            if model.missingMacCameraAccess != nil {
                MacCameraWarning()
            }
            // Through the route, like the menu of the main screen: the reports then open their
            // details in the same navigation stack.
            NavigationLink(value: AppRoute.intrusions) {
                Label("Break-in reports", systemImage: "photo.stack")
            }
            .badge(model.intrusions.unseenCount)
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text("Locky on your Mac will send you a photo if someone tries to unlock it while you're not there. Photos are stored in your iCloud account.")
                OutOfReachNote()
            }
        }
    }
}

private struct LockAnimationSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let status: MacStatus? = model.macStatus
        Section {
            NavigationLink {
                MacAnimationSettingsView()
            } label: {
                Label("Lock animation", systemImage: "sparkles")
            }
            .disabled(status?.supports(.lockAnimation) != true)
        } footer: {
            if status != nil, status?.supports(.lockAnimation) != true {
                Text("Update Locky on your Mac to choose its lock animation from here.")
            }
        }
    }
}

/// Out of reach, how a change of a setting the Mac applies gets to it.
struct OutOfReachNote: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if !model.isConnected {
            if model.macStatus?.supports(.cloudSettings) == true {
                Text("Your Mac is out of reach: it will receive the change through iCloud.")
            } else {
                Text("Your Mac will receive the change when it is back in reach.")
            }
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
                    lockState: model.lockState,
                    isMoving: model.isMoving,
                    family: model.macStatus?.family ?? .unknown,
                    phoneImage: model.visuals.phone,
                    onCommit: model.preferencesDidChange
                )
            }
            .padding(.vertical, 6)
            // Grayed out while the Mac is out of reach: no live distance. The lock distance can still
            // be set, the Mac gets it when it connects.
            .saturation(model.isConnected ? 1 : 0)
            .fadedWhileOutOfReach(!model.isConnected)
            // Calibrating needs the Mac.
            Button("Calibrate the distance", systemImage: "scope") {
                isCalibrating = true
            }
            .disabled(!model.isConnected)
            .fadedWhileOutOfReach(!model.isConnected)
            .sheet(isPresented: $isCalibrating) {
                DistanceCalibrationView()
            }
        } footer: {
            Text(footer)
        }
    }

    private var footer: String {
        let adjust: String = .init(localized: "Adjust the lock distance by moving the padlock.")
        // Out of reach: why, as on the main screen ("Looking for your Mac…", "Bluetooth is off"…).
        guard model.isConnected else { return model.connectionSummary + " " + adjust }
        guard let distance = model.proximity?.distance else { return adjust }
        let formatted: String = Measurement(value: distance, unit: UnitLength.meters).formatted(.lockyDistance)
        return adjust + " " + String(localized: "Your iPhone is about \(formatted) from your Mac.")
    }
}

/// Locky on the Mac: its version and its updates, its release notes.
private struct MacAppSection: View {
    @Environment(AppModel.self) private var model
    /// The Mac was just asked to check: for a few seconds, a word says where to look.
    @State private var hasAskedMac: Bool = false

    var body: some View {
        let status: MacStatus? = model.macStatus
        Section {
            LabeledContent {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(verbatim: status?.appVersion ?? String(localized: "1.0.1 or earlier"))
                    if model.macReleases != nil, model.availableMacUpdate == nil, status != nil {
                        Text("Up to date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } label: {
                Label("Version", systemImage: "desktopcomputer")
            }
            if let update = model.availableMacUpdate {
                if status?.supports(.macUpdates) == true {
                    Button {
                        model.updateMac()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Update to Locky \(update.version)")
                                Text("Opens the update window on your Mac.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                    }
                    .disabled(!model.isConnected)
                } else {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Locky \(update.version) is available for your Mac.")
                            Text("Choose “Check for updates…” in the Locky menu on your Mac.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }
            } else if status?.supports(.macUpdates) == true {
                // As "Check for updates…" in the menu of the Mac: Sparkle answers there, with the
                // new version or "You're up to date".
                Button {
                    checkForUpdates()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Check for updates")
                            Text(checkCaption)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .contentTransition(.opacity)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(!model.isConnected)
                .sensoryFeedback(.success, trigger: hasAskedMac) { _, asked in asked }
            }
            NavigationLink {
                ReleaseNotesView()
            } label: {
                Label("Release notes", systemImage: "doc.text")
            }
        } header: {
            Text("Locky for Mac")
        }
    }

    private var checkCaption: LocalizedStringKey {
        if hasAskedMac {
            return "Done! Have a look at your Mac."
        }
        return model.isConnected ? "Your Mac looks for a new version and shows you the answer." : "Your Mac must be in reach."
    }

    private func checkForUpdates() {
        model.updateMac()
        withAnimation { hasAskedMac = true }
        Task {
            // The iPhone checks too, to show the new version here if there is one.
            await model.loadMacReleases()
            try? await Task.sleep(for: .seconds(4))
            withAnimation { hasAskedMac = false }
        }
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
            Button(role: .destructive) {
                isConfirmingUnpair = true
            } label: {
                // The icon takes the tint of the list, not the red of the destructive title: red by hand.
                Label {
                    Text("Forget this Mac")
                } icon: {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                }
            }
        }
    }
}
