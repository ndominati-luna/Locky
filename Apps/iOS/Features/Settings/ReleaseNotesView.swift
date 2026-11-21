import LockyKit
import SwiftUI

/// The versions of Locky for Mac and what each one brought, read from the Sparkle feed of the site.
struct ReleaseNotesView: View {
    @Environment(AppModel.self) private var model
    @State private var isUnavailable: Bool = false

    var body: some View {
        Group {
            if let releases = model.macReleases {
                List(releases) { release in
                    Section {
                        if release.noteLines.isEmpty {
                            Text("No notes for this version.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(release.noteLines, id: \.self) { line in
                                Label {
                                    Text((try? AttributedString(markdown: line)) ?? AttributedString(line))
                                } icon: {
                                    Image(systemName: "sparkle")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    } header: {
                        ReleaseHeader(release: release, isInstalled: release.build == model.macStatus?.appBuild)
                    }
                }
                .scrollContentBackground(.hidden)
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
        .navigationTitle("Release notes")
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.55, isFaded: !model.isConnected)
        .task {
            if model.macReleases == nil {
                isUnavailable = !(await model.loadMacReleases())
            }
        }
    }
}

/// "Locky 1.0.2", installed or not, and its date.
private struct ReleaseHeader: View {
    let release: MacRelease
    let isInstalled: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: "Locky \(release.version)")
                .font(.headline)
                .foregroundStyle(.primary)
            if isInstalled {
                Text("Installed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.18), in: .capsule)
            }
            Spacer()
            if let date = release.date {
                Text(date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
            }
        }
        .textCase(nil)
    }
}
