import LockyKit
import SwiftUI

/// Full size photo of an intrusion.
struct IntrusionDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let report: IntrusionReport

    var body: some View {
        VStack(spacing: 16) {
            if let image = report.photo.flatMap(UIImage.init(data:)) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: 16))
                    .accessibilityLabel(Text("Photo of the intruder"))
            } else {
                ContentUnavailableView(
                    "No photo",
                    systemImage: "camera.badge.ellipsis",
                    description: Text("The camera of your Mac was not available.")
                )
            }
            Text(report.date, format: .dateTime.weekday(.wide).day().month().hour().minute())
                .font(.headline)
            Text(report.macName)
                .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Break-in attempt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let image = report.photo.flatMap(UIImage.init(data:)) {
                ToolbarItem {
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview(Text("Break-in attempt"), image: Image(uiImage: image))
                    )
                }
            }
            ToolbarItem {
                Button("Delete", systemImage: "trash", role: .destructive) {
                    Task {
                        await model.intrusions.delete(report)
                        dismiss()
                    }
                }
            }
        }
    }
}
