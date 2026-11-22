import SwiftUI

/// About Locky, in a sheet over the wallpaper of the Mac like the main screen: the logo assembles
/// itself, then the version and the sites of Locky and of Lunabee Studio, opened inside the app.
/// Tapping the logo once per year since the first Locky opens its video (``LockyStoryView``,
/// presented by ``MainView``).
struct AboutView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var openedSite: OpenedSite?
    @State private var logoTaps: Int = 0
    @State private var lastLogoTap: Date = .distantPast
    /// Success feedback when the right number of taps is reached.
    @State private var hasFoundStory: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    AboutHeader(logoTaps: logoTaps, onLogoTap: tapLogo)
                    GlassEffectContainer(spacing: 12) {
                        VStack(spacing: 12) {
                            SiteButton(
                                title: "Visit the Locky website",
                                address: "locky.lunabee.studio",
                                open: { openedSite = .init(url: Self.lockySite) }
                            ) {
                                Image(.lockyGlyph)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(10)
                            }
                            SiteButton(
                                title: "Discover Lunabee Studio",
                                address: "lunabee.studio",
                                open: { openedSite = .init(url: Self.studioSite) }
                            ) {
                                Image(.lunabeeStudioLogo)
                                    .resizable()
                                    .scaledToFit()
                                    .padding(11)
                            }
                            NavigationLink {
                                ReleaseNotesView()
                            } label: {
                                AboutRow(title: "Release notes", subtitle: Text("Locky for Mac"), trailingSymbol: "chevron.right") {
                                    Image(systemName: "doc.text")
                                        .resizable()
                                        .scaledToFit()
                                        .padding(13)
                                }
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
                        }
                    }
                    StudioSignature()
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .safari($openedSite)
        .sensoryFeedback(.success, trigger: hasFoundStory) { _, hasFound in hasFound }
        .presentationBackground {
            ImmersiveBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.5, isFaded: !model.isConnected)
        }
    }

    /// Taps in a row (less than a second and a half apart) count; the right number closes About
    /// and opens the video from the main screen.
    private func tapLogo() {
        let now: Date = .now
        logoTaps = now.timeIntervalSince(lastLogoTap) < 1.5 ? logoTaps + 1 : 1
        lastLogoTap = now
        guard logoTaps == LockyStory.tapCount else { return }
        logoTaps = 0
        hasFoundStory = true
        dismiss()
        Task { [model] in
            // Once the sheet is gone: one presentation at a time.
            try? await Task.sleep(for: .milliseconds(450))
            model.isStoryPresented = true
        }
    }

    private static let lockySite: URL = .init(string: "https://locky.lunabee.studio")!
    private static let studioSite: URL = .init(string: "https://lunabee.studio")!
}

/// The logo assembling itself, the name, the version and what Locky does.
private struct AboutHeader: View {
    /// Taps in a row on the logo: each one makes it jump a little.
    let logoTaps: Int
    let onLogoTap: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Button(action: onLogoTap) {
                LockyAssemblyIllustration()
                    .frame(height: 150)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .phaseAnimator([1, 1.06, 1], trigger: logoTaps) { logo, scale in
                logo.scaleEffect(logoTaps > 0 ? scale : 1)
            } animation: { _ in
                .spring(duration: 0.18)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: logoTaps) { _, taps in taps > 0 }
            // A secret: nothing to announce.
            .accessibilityHidden(true)
            .padding(.top, 8)
            VStack(spacing: 10) {
                Text(verbatim: "Locky")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Version \(LocalDevice.appVersion)")
                    .font(.footnote.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .glassEffect(.regular, in: .capsule)
            }
            Text("Locky locks your Mac when you walk away with your iPhone and unlocks it when you come back.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// A site to open: its icon, an invitation and its address.
private struct SiteButton<Icon: View>: View {
    let title: LocalizedStringKey
    let address: String
    let open: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        Button(action: open) {
            AboutRow(title: title, subtitle: Text(verbatim: address), trailingSymbol: "arrow.up.right") {
                icon
            }
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 24))
        .accessibilityHint(Text(verbatim: address))
    }
}

/// A row of the About sheet: an icon in a glass circle, a title, a subtitle and a symbol saying
/// where it leads.
private struct AboutRow<Icon: View>: View {
    let title: LocalizedStringKey
    let subtitle: Text
    let trailingSymbol: String
    @ViewBuilder var icon: Icon

    var body: some View {
        HStack(spacing: 14) {
            icon
                .foregroundStyle(Color.brandArt)
                .frame(width: 48, height: 48)
                .glassEffect(.regular, in: .circle)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                subtitle
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: trailingSymbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .contentShape(.rect)
    }
}

/// Who made Locky.
private struct StudioSignature: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("Locky is designed and built by Lunabee Studio.")
                .font(.footnote)
                .multilineTextAlignment(.center)
            Text(verbatim: "© \(Date.now.formatted(.dateTime.year())) Lunabee Studio")
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.top, 8)
    }
}
