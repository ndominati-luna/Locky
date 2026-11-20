import LockyKit
import SwiftUI
import WidgetKit

@main
struct LockyWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        MacStatusComplication()
    }
}

/// Watch complication showing the lock state of the Mac.
struct MacStatusComplication: Widget {
    let kind: String = "MacStatusComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ComplicationProvider()) { entry in
            ComplicationView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("My Mac")
        .description("Lock state of your Mac.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}

struct ComplicationEntry: TimelineEntry {
    let date: Date
    let snapshot: LockySnapshot
}

struct ComplicationProvider: TimelineProvider {
    func placeholder(in context: Context) -> ComplicationEntry {
        .init(date: .now, snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (ComplicationEntry) -> Void) {
        completion(.init(date: .now, snapshot: context.isPreview ? .preview : SharedStore.snapshot()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ComplicationEntry>) -> Void) {
        completion(Timeline(entries: [.init(date: .now, snapshot: SharedStore.snapshot())], policy: .never))
    }
}

struct ComplicationView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ComplicationEntry

    private var symbol: String {
        entry.snapshot.isConnected ? entry.snapshot.lockState.systemImage : "antenna.radiowaves.left.and.right.slash"
    }

    var body: some View {
        switch family {
        case .accessoryRectangular:
            VStack(alignment: .leading) {
                Text(entry.snapshot.macName ?? "Locky")
                    .font(.headline)
                    .widgetAccentable()
                Label(entry.snapshot.localizedStatus, systemImage: symbol)
                    .font(.caption)
            }
        case .accessoryInline:
            Label(entry.snapshot.localizedStatus, systemImage: symbol)
        case .accessoryCorner:
            Image(systemName: symbol)
                .font(.title3)
                .widgetLabel(entry.snapshot.localizedStatus)
        default:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: symbol)
                    .font(.title3)
                    .widgetAccentable()
            }
        }
    }
}
