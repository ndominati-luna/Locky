import LockyKit
import SwiftUI

/// Photos taken by the Mac when someone tried to use it while the iPhone was away.
struct IntrusionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        let store: IntrusionStore = model.intrusions
        Group {
            if !store.isCloudAvailable {
                ContentUnavailableView(
                    "iCloud unavailable",
                    systemImage: "icloud.slash",
                    description: Text("Sign in to iCloud on your iPhone and your Mac with the same Apple Account to receive break-in reports.")
                )
            } else if store.reports.isEmpty {
                EmptyIntrusionsView()
            } else {
                List {
                    if model.missingMacCameraAccess != nil {
                        Section {
                            MacCameraWarning()
                        }
                    }
                    ForEach(sections, id: \.title) { section in
                        Section(section.title) {
                            ForEach(section.reports) { report in
                                NavigationLink(value: report) {
                                    IntrusionRow(report: report)
                                }
                            }
                            .onDelete { offsets in
                                let reports: [IntrusionReport] = offsets.map { section.reports[$0] }
                                Task {
                                    for report in reports {
                                        await store.delete(report)
                                    }
                                }
                            }
                        }
                    }
                }
                .navigationDestination(for: IntrusionReport.self) { report in
                    IntrusionDetailView(report: report)
                }
            }
        }
        .navigationTitle("Break-in reports")
        .scrollContentBackground(.hidden)
        .immersivePageBackground(intensity: 0.5)
        .overlay {
            if store.isLoading, store.reports.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await model.refreshFromCloud()
        }
        .task {
            await model.refreshFromCloud()
            store.markAllSeen()
        }
        .onChange(of: store.reports) {
            store.markAllSeen()
        }
    }

    private var sections: [IntrusionSection] {
        let calendar: Calendar = .current
        let grouped: [Date: [IntrusionReport]] = Dictionary(grouping: model.intrusions.reports) {
            calendar.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            let title: String
            if calendar.isDateInToday(day) {
                title = String(localized: "Today")
            } else if calendar.isDateInYesterday(day) {
                title = String(localized: "Yesterday")
            } else {
                title = day.formatted(date: .complete, time: .omitted)
            }
            return .init(title: title, reports: grouped[day] ?? [])
        }
    }
}

private struct IntrusionSection {
    let title: String
    let reports: [IntrusionReport]
}

/// One report in the list.
private struct IntrusionRow: View {
    let report: IntrusionReport

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let image = report.photo.flatMap(UIImage.init(data:)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "person.crop.square.badge.camera")
                        .font(.title)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(.rect(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(report.date, format: .dateTime.hour().minute())
                    .font(.headline)
                Text(report.macName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Explains the feature when there is no report.
private struct EmptyIntrusionsView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        @Bindable var preferences = model.preferences
        ContentUnavailableView {
            Label("No break-in attempt", systemImage: "checkmark.shield")
        } description: {
            Text("When intruder detection is on, your Mac takes a photo of anyone trying to use it while you're away and sends it here.")
        } actions: {
            if !preferences.intrusionDetection {
                Button("Turn on intruder detection") {
                    preferences.intrusionDetection = true
                    model.preferencesDidChange()
                }
                .buttonStyle(.glassProminent)
            } else if model.missingMacCameraAccess != nil {
                MacCameraWarning()
                    .frame(maxWidth: 360)
            }
        }
    }
}
