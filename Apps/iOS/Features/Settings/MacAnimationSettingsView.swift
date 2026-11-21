import LockyKit
import SwiftUI

/// The lock animation of the Mac, chosen from the iPhone: previewed here over the wallpaper of the
/// Mac, applied by the Mac at once. The background image can only be chosen on the Mac.
struct MacAnimationSettingsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorScheme) private var colorScheme
    /// Dark colors the logo stands out on, as on the Mac.
    private static let swatches: [String] = ["000000", "0B1E3F", "2B1240", "0F2E25", "3B1016"]

    var body: some View {
        Form {
            if let settings = model.macLockAnimation {
                let isAnimated: Bool = settings.style != .none
                Section {
                    // The full wallpaper (the small copy of the blurred backgrounds is pixelated here).
                    LockAnimationPreview(
                        animation: Self.animation(settings),
                        backdrop: Self.backdrop(settings),
                        desktop: model.visuals.wallpaperImage
                    )
                    .aspectRatio(16 / 10, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 22))
                    .overlay {
                        // A hairline edge, so that the card stands apart from a background of the same tone.
                        RoundedRectangle(cornerRadius: 22)
                            .strokeBorder(.white.opacity(colorScheme == .dark ? 0.14 : 0.4), lineWidth: 0.5)
                    }
                    // Darker in dark mode, where a light shadow would vanish.
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.5 : 0.18), radius: 8, y: 10)
                    // Room for the shadow: the row clips what goes beyond it.
                    .padding(.init(top: 6, leading: 12, bottom: 28, trailing: 12))
                    .listRowInsets(.init())
                    .listRowBackground(Color.clear)
                }
                Section {
                    Picker("Animation", selection: binding(\.style)) {
                        ForEach(LockAnimationStyle.allCases) { style in
                            Text(style.name).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                } header: {
                    Text("Animation")
                } footer: {
                    Text(settings.style.summary)
                }

                Section {
                    TextField("Text under the logo", text: titleBinding, prompt: Text(verbatim: "Locky"))
                    Picker("Appearance", selection: binding(\.titleStyle)) {
                        ForEach(LockTitleStyle.allCases) { style in
                            Text(style.name).tag(style)
                        }
                    }
                } header: {
                    Text("Text")
                } footer: {
                    Text("Appears under the Locky logo when your Mac locks. Leave empty to show “Locky”.")
                }
                .disabled(!isAnimated)

                Section {
                    Picker("Background", selection: binding(\.backgroundKind)) {
                        ForEach(LockBackgroundKind.allCases.filter { $0 != .image || settings.hasBackgroundImage }) { kind in
                            Text(kind.name).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(.init())
                    if settings.backgroundKind == .color {
                        ColorRow(selection: settings.backgroundColor, swatches: Self.swatches) { hex in
                            var changed: LockAnimationSettings = settings
                            changed.backgroundColor = hex
                            model.setMacLockAnimation(changed)
                        }
                    }
                } header: {
                    Text("Background")
                } footer: {
                    if !settings.hasBackgroundImage {
                        Text("An image can also be chosen on your Mac, in the animation window of the Locky menu.")
                    }
                }
                .disabled(!isAnimated)

                Section {
                    Button("Preview on your Mac", systemImage: "play.rectangle") {
                        model.previewMacLockAnimation()
                    }
                    .disabled(!isAnimated)
                } footer: {
                    Text("Plays the animation on your Mac without locking it.")
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }
        }
        .disabled(!model.isConnected)
        .navigationTitle("Lock animation")
        .scrollContentBackground(.hidden)
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.55, isFaded: !model.isConnected)
    }

    /// A setting of the animation, sent to the Mac as soon as it changes.
    private func binding<Value>(_ keyPath: WritableKeyPath<LockAnimationSettings, Value>) -> Binding<Value> {
        .init(
            get: {
                guard let settings = model.macLockAnimation else { return Self.placeholder[keyPath: keyPath] }
                return settings[keyPath: keyPath]
            },
            set: { value in
                guard var settings = model.macLockAnimation else { return }
                settings[keyPath: keyPath] = value
                model.setMacLockAnimation(settings)
            }
        )
    }

    private var titleBinding: Binding<String> {
        .init(
            get: { model.macLockAnimation?.title ?? "" },
            set: { title in
                guard var settings = model.macLockAnimation else { return }
                settings.title = String(title.prefix(LockAnimationSettings.maximumTitleLength))
                model.setMacLockAnimation(settings)
            }
        )
    }

    /// What the preview plays.
    private static func animation(_ settings: LockAnimationSettings) -> LockAnimation {
        let title: String = settings.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return .init(
            style: settings.style,
            title: title.isEmpty ? "Locky" : title,
            titleStyle: settings.titleStyle,
            background: .init(kind: settings.backgroundKind, colorHex: settings.backgroundColor)
        )
    }

    /// The image chosen on the Mac stays there: black stands for it.
    private static func backdrop(_ settings: LockAnimationSettings) -> LockBackdrop {
        switch settings.backgroundKind {
        case .color: .color(Color(hex: settings.backgroundColor))
        case .wallpaper: .wallpaper
        case .image: .color(.black)
        }
    }

    private static let placeholder: LockAnimationSettings = .init(
        style: .iris,
        title: "",
        titleStyle: .reveal,
        backgroundKind: .color,
        backgroundColor: "000000",
        hasBackgroundImage: false
    )
}

/// The color behind the logo: a few dark colors, or any other.
private struct ColorRow: View {
    let selection: String
    let swatches: [String]
    let choose: (String) -> Void

    var body: some View {
        HStack(spacing: 12) {
            ForEach(swatches, id: \.self) { hex in
                Button {
                    choose(hex)
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 30, height: 30)
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                        }
                        .padding(3)
                        .overlay {
                            Circle()
                                .strokeBorder(selection.uppercased() == hex ? Color.accentColor : .clear, lineWidth: 2.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: "#\(hex)"))
                .accessibilityAddTraits(selection.uppercased() == hex ? .isSelected : [])
            }
            Spacer(minLength: 0)
            ColorPicker(
                "Other color",
                selection: .init(get: { Color(hex: selection) }, set: { choose($0.hex) }),
                supportsOpacity: false
            )
            .labelsHidden()
        }
    }
}
