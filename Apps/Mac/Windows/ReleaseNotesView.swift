import LockyKit
import SwiftUI

/// The versions of Locky for Mac and what each one brought, read from the Sparkle feed of the site.
struct ReleaseNotesView: View {
    @Environment(\.closeWindow) private var closeWindow
    @State private var releases: [MacRelease]?
    @State private var isUnavailable: Bool = false

    private var currentBuild: Int? {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String).flatMap { Int($0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let releases {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 24) {
                            ForEach(releases) { release in
                                ReleaseSection(release: release, isInstalled: release.build == currentBuild)
                            }
                        }
                        .padding(24)
                    }
                } else if isUnavailable {
                    ContentUnavailableView(
                        "Release notes unavailable",
                        systemImage: "wifi.slash",
                        description: Text("Check your internet connection.")
                    )
                } else {
                    ProgressView()
                }
            }
            .frame(width: 500, height: 440)
            Divider()
            HStack {
                Spacer()
                Button("Done") {
                    closeWindow()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .task {
            do {
                releases = try await MacReleaseFeed.fetch()
            } catch {
                isUnavailable = true
            }
        }
    }
}

/// One version: its number, its date and its notes.
private struct ReleaseSection: View {
    let release: MacRelease
    let isInstalled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(verbatim: "Locky \(release.version)")
                    .font(.title3.bold())
                if isInstalled {
                    Text("Installed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.15), in: .capsule)
                }
                Spacer()
                if let date = release.date {
                    Text(date, format: .dateTime.day().month(.wide).year())
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            if release.noteLines.isEmpty {
                Text("No notes for this version.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(release.noteLines, id: \.self) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "•")
                            .foregroundStyle(.secondary)
                        Text((try? AttributedString(markdown: line)) ?? AttributedString(line))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .textSelection(.enabled)
    }
}
