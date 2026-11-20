import SwiftUI

/// Customizes the text that appears under the Locky logo when the Mac locks.
struct AnimationSettingsView: View {
    @Environment(MacAppModel.self) private var model
    @Environment(\.closeWindow) private var closeWindow
    /// Changing it plays the preview again.
    @State private var replay: Int = 0
    private static let maximumLength: Int = 24

    var body: some View {
        @Bindable var preferences = model.preferences
        VStack(alignment: .leading, spacing: 18) {
            ZStack {
                Color.black
                AnimatedLockyLogo(title: preferences.effectiveLockAnimationTitle, size: 120)
                    // The title hangs below the logo: center the whole.
                    .offset(y: -18)
                    .id(replay)
            }
            .frame(height: 230)
            .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                TextField("Text under the logo", text: $preferences.lockAnimationTitle, prompt: Text(verbatim: "Locky"))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { replay += 1 }
                    .onChange(of: preferences.lockAnimationTitle) { _, title in
                        if title.count > Self.maximumLength {
                            preferences.lockAnimationTitle = String(title.prefix(Self.maximumLength))
                        }
                    }
                Text("Appears under the Locky logo when your Mac locks. Leave empty to show “Locky”.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Replay", systemImage: "arrow.counterclockwise") {
                    replay += 1
                }
                Button("Full screen preview", systemImage: "play.rectangle") {
                    model.previewLockAnimation()
                }
                Spacer()
                Button("Done") {
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
    }
}
