import LockyKit
import SwiftUI

/// A break-in attempt: the photo taken by the Mac, when and on which Mac, to share or delete.
struct IntrusionDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let reportID: String

    /// The report from the store: `nil` once deleted (here or from another device).
    private var report: IntrusionReport? {
        model.intrusions.reports.first { $0.id == reportID }
    }

    var body: some View {
        Group {
            if let report {
                IntrusionDetailContent(report: report, macSymbol: (model.macStatus?.family ?? .unknown).systemImage)
                    .toolbar {
                        IntrusionDetailToolbar(report: report) {
                            // Back first: the screen would otherwise show an empty report.
                            dismiss()
                            Task { await model.intrusions.delete(report) }
                        }
                    }
            } else {
                Color.clear
            }
        }
        .navigationTitle("Break-in attempt")
        .navigationBarTitleDisplayMode(.inline)
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.5, isFaded: !model.isConnected)
        .onChange(of: report == nil) { _, isDeleted in
            if isDeleted { dismiss() }
        }
    }
}

/// The photo, then the date, the time and the Mac.
private struct IntrusionDetailContent: View {
    let report: IntrusionReport
    let macSymbol: String

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                IntrusionPhoto(photo: report.photo)
                VStack(spacing: 6) {
                    Text(report.date, format: .dateTime.weekday(.wide).day().month(.wide).year())
                        .font(.title3.bold())
                    Text(report.date, format: .dateTime.hour().minute().second())
                        .font(.headline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Label(report.macName, systemImage: macSymbol)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
                .multilineTextAlignment(.center)
                .accessibilityElement(children: .combine)
            }
            .padding()
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }
}

/// The photo of the intruder, as large as the screen allows; a placeholder without a camera.
private struct IntrusionPhoto: View {
    let photo: Data?

    var body: some View {
        if let image = photo.flatMap(UIImage.init(data:)) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(.rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 12, y: 4)
                .accessibilityLabel(Text("Photo of the intruder"))
        } else {
            ContentUnavailableView(
                "No photo",
                systemImage: "camera.badge.ellipsis",
                description: Text("The camera of your Mac was not available.")
            )
            .frame(minHeight: 240)
            .background(.ultraThinMaterial, in: .rect(cornerRadius: 20))
        }
    }
}

/// Share the photo, delete the report.
private struct IntrusionDetailToolbar: ToolbarContent {
    let report: IntrusionReport
    let onDelete: () -> Void

    var body: some ToolbarContent {
        if let image = report.photo.flatMap(UIImage.init(data:)) {
            ToolbarItem {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(Text("Break-in attempt"), image: Image(uiImage: image))
                )
            }
        }
        ToolbarItem {
            Button("Delete", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}
