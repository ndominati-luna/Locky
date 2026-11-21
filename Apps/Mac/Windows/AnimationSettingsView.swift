import LockyKit
import SwiftUI
import UniformTypeIdentifiers

/// Customizes the lock animation: its style (none included), the text under the logo and how it
/// appears, and its background. The preview plays the choice in a loop over the wallpaper.
struct AnimationSettingsView: View {
    @Environment(MacAppModel.self) private var model
    @Environment(\.closeWindow) private var closeWindow
    @State private var desktop: NSImage?
    @State private var isChoosingImage: Bool = false
    @State private var isImageRefused: Bool = false
    private static let maximumLength: Int = 24
    /// Dark colors the logo stands out on, before the color picker.
    private static let swatches: [String] = ["000000", "0B1E3F", "2B1240", "0F2E25", "3B1016"]

    var body: some View {
        @Bindable var preferences = model.preferences
        let animation: LockAnimation = preferences.lockAnimation
        let isAnimated: Bool = preferences.lockAnimationStyle != .none
        VStack(alignment: .leading, spacing: 20) {
            LockAnimationPreview(animation: animation, backdrop: animation.background.backdrop, desktop: desktop)
                .frame(maxWidth: .infinity)
                .frame(height: 320)
                .clipShape(.rect(cornerRadius: 14))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(.separator)
                }
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 14, verticalSpacing: 10) {
                GridRow {
                    Text("Animation")
                        .gridColumnAlignment(.trailing)
                    Picker("Animation", selection: $preferences.lockAnimationStyle) {
                        ForEach(LockAnimationStyle.allCases) { style in
                            Text(style.name).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                GridRow {
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                    Caption(preferences.lockAnimationStyle.summary)
                }
                Divider()
                    .padding(.vertical, 4)
                GridRow {
                    Text("Text")
                    TextField("Text under the logo", text: $preferences.lockAnimationTitle, prompt: Text(verbatim: "Locky"))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .disabled(!isAnimated)
                        .onChange(of: preferences.lockAnimationTitle) { _, title in
                            if title.count > Self.maximumLength {
                                preferences.lockAnimationTitle = String(title.prefix(Self.maximumLength))
                            }
                        }
                }
                GridRow {
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                    Caption("Appears under the Locky logo when your Mac locks. Leave empty to show “Locky”.")
                }
                GridRow {
                    Text("Appearance")
                    Picker("Appearance", selection: $preferences.lockTitleStyle) {
                        ForEach(LockTitleStyle.allCases) { style in
                            Text(style.name).tag(style)
                        }
                    }
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!isAnimated)
                }
                Divider()
                    .padding(.vertical, 4)
                GridRow {
                    Text("Background")
                    Picker("Background", selection: $preferences.lockBackgroundKind) {
                        ForEach(LockBackgroundKind.allCases) { kind in
                            Text(kind.name).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                    .disabled(!isAnimated)
                }
                GridRow {
                    Color.clear
                        .gridCellUnsizedAxes([.horizontal, .vertical])
                    backgroundDetail
                        .disabled(!isAnimated)
                }
            }
            HStack {
                Button("Full screen preview", systemImage: "play.rectangle") {
                    model.previewLockAnimation()
                }
                .disabled(!isAnimated)
                Spacer()
                Button("Done") {
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 560)
        .task {
            desktop = await model.lockAnimationDesktop()
        }
        .onChange(of: preferences.lockAnimationSettings) {
            model.lockAnimationDidChange()
        }
        .onChange(of: preferences.lockBackgroundKind) { _, kind in
            // No image chosen yet: choose one now.
            if kind == .image, LockBackgroundImage.image(version: preferences.lockBackgroundImageVersion) == nil {
                isChoosingImage = true
            }
        }
        .fileImporter(isPresented: $isChoosingImage, allowedContentTypes: [.image]) { result in
            guard case let .success(url) = result else { return }
            if LockBackgroundImage.store(from: url) {
                preferences.lockBackgroundImageVersion += 1
                preferences.lockBackgroundKind = .image
            } else {
                isImageRefused = true
            }
        }
        .alert("Locky can't read this image.", isPresented: $isImageRefused) {
            Button("OK") {}
        }
    }

    @ViewBuilder
    private var backgroundDetail: some View {
        let preferences: MacPreferences = model.preferences
        switch preferences.lockBackgroundKind {
        case .color:
            HStack(spacing: 8) {
                ForEach(Self.swatches, id: \.self) { hex in
                    Swatch(color: Color(hex: hex), isSelected: preferences.lockBackgroundColor == hex) {
                        preferences.lockBackgroundColor = hex
                    }
                }
                ColorPicker(
                    "Other color",
                    selection: .init(
                        get: { Color(hex: preferences.lockBackgroundColor) },
                        set: { preferences.lockBackgroundColor = $0.hex }
                    ),
                    supportsOpacity: false
                )
                .labelsHidden()
            }
        case .wallpaper:
            Caption("The wallpaper of each display, blurred.")
        case .image:
            HStack(spacing: 10) {
                if let image = LockBackgroundImage.image(version: preferences.lockBackgroundImageVersion) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 40)
                        .clipShape(.rect(cornerRadius: 6))
                        .accessibilityHidden(true)
                }
                Button("Choose an image…") {
                    isChoosingImage = true
                }
            }
        }
    }
}

/// A gray explanation under a setting.
private struct Caption: View {
    let text: LocalizedStringKey

    init(_ text: LocalizedStringKey) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A background color to pick in one click.
private struct Swatch: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
                .padding(3)
                .overlay {
                    Circle()
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(verbatim: "#\(color.hex)"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
