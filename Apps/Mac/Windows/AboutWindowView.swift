import SwiftUI

/// About Locky, like on the iPhone: the logo assembles itself, then the version, the sites of
/// Locky and of Lunabee Studio and the release notes. Clicking the logo once per year since the
/// first Locky opens its video (``StoryWindowView``).
struct AboutWindowView: View {
    let openReleaseNotes: () -> Void
    let openStory: () -> Void
    @Environment(\.openURL) private var openURL
    @State private var logoClicks: Int = 0
    @State private var lastLogoClick: Date = .distantPast

    var body: some View {
        VStack(spacing: 24) {
            AboutHeader(logoClicks: logoClicks, onLogoClick: clickLogo)
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    AboutRow(title: "Visit the Locky website", subtitle: Text(verbatim: "locky.lunabee.studio"), trailingSymbol: "arrow.up.right") {
                        openURL(Self.lockySite)
                    } icon: {
                        Image(.lockyGlyph)
                            .resizable()
                            .scaledToFit()
                            .padding(8)
                    }
                    AboutRow(title: "Discover Lunabee Studio", subtitle: Text(verbatim: "lunabee.studio"), trailingSymbol: "arrow.up.right") {
                        openURL(Self.studioSite)
                    } icon: {
                        Image(.lunabeeStudioLogo)
                            .resizable()
                            .scaledToFit()
                            .padding(9)
                    }
                    AboutRow(title: "Release notes", subtitle: Text("Locky for Mac"), trailingSymbol: "chevron.right", action: openReleaseNotes) {
                        Image(systemName: "doc.text")
                            .resizable()
                            .scaledToFit()
                            .padding(10)
                    }
                }
            }
            VStack(spacing: 4) {
                Text("Locky is designed and built by Lunabee Studio.")
                    .font(.footnote)
                Text(verbatim: "© \(Date.now.formatted(.dateTime.year())) Lunabee Studio")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 28)
        .padding(.top, 36)
        .padding(.bottom, 24)
        .frame(width: 400)
        .background {
            BrandBackground()
        }
    }

    /// Clicks in a row (less than a second and a half apart) count; the right number closes About
    /// and opens the video.
    private func clickLogo() {
        let now: Date = .now
        logoClicks = now.timeIntervalSince(lastLogoClick) < 1.5 ? logoClicks + 1 : 1
        lastLogoClick = now
        guard logoClicks == LockyStory.tapCount else { return }
        logoClicks = 0
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        openStory()
    }

    private static let lockySite: URL = .init(string: "https://locky.lunabee.studio")!
    private static let studioSite: URL = .init(string: "https://lunabee.studio")!
}

/// The logo assembling itself, the name, the version and what Locky does.
private struct AboutHeader: View {
    /// Clicks in a row on the logo: each one makes it jump a little.
    let logoClicks: Int
    let onLogoClick: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onLogoClick) {
                LockyAssemblyIllustration()
                    .frame(height: 120)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .focusable(false)
            .phaseAnimator([1, 1.06, 1], trigger: logoClicks) { logo, scale in
                logo.scaleEffect(logoClicks > 0 ? scale : 1)
            } animation: { _ in
                .spring(duration: 0.18)
            }
            // A secret: nothing to announce.
            .accessibilityHidden(true)
            VStack(spacing: 8) {
                Text(verbatim: "Locky")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Version \(MacDeviceInfo.appVersion)")
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

/// A row of About: an icon in a glass circle, a title, a subtitle and a symbol saying where it
/// leads.
private struct AboutRow<Icon: View>: View {
    let title: LocalizedStringKey
    let subtitle: Text
    let trailingSymbol: String
    let action: () -> Void
    @ViewBuilder var icon: Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                icon
                    .foregroundStyle(Color.brandArt)
                    .frame(width: 38, height: 38)
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
            .padding(10)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
    }
}
