import AppKit
import LockyKit
import SwiftUI
import WidgetKit

/// Desktop widget: the paired iPhone, its distance and battery, and Locky's state.
struct PhoneStatusWidget: Widget {
    let kind: String = "PhoneStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PhoneStatusProvider()) { entry in
            PhoneStatusWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("My iPhone")
        .description("See whether your iPhone is close to your Mac and control Locky.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct PhoneStatusEntry: TimelineEntry {
    let date: Date
    let state: MacWidgetState
    let phoneImage: Data?

    static let preview: PhoneStatusEntry = .init(date: .now, state: .preview, phoneImage: nil)
}

/// The Mac app reloads the timelines on every meaningful change: one entry is enough.
struct PhoneStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> PhoneStatusEntry {
        .preview
    }

    func getSnapshot(in context: Context, completion: @escaping (PhoneStatusEntry) -> Void) {
        completion(context.isPreview ? .preview : currentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PhoneStatusEntry>) -> Void) {
        completion(Timeline(entries: [currentEntry()], policy: .never))
    }

    private func currentEntry() -> PhoneStatusEntry {
        .init(date: .now, state: MacSharedStore.state(), phoneImage: MacSharedStore.phoneImage)
    }
}

struct PhoneStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PhoneStatusEntry

    private var state: MacWidgetState { entry.state }

    var body: some View {
        if !state.isPaired {
            VStack(spacing: 8) {
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("Pair your iPhone from the Locky menu.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        } else if family == .systemMedium {
            HStack(spacing: 14) {
                PhoneImage(data: entry.phoneImage, isConnected: state.isConnected)
                VStack(alignment: .leading, spacing: 6) {
                    PhoneInfo(state: state)
                    Spacer(minLength: 0)
                    HStack {
                        Toggle(isOn: state.isAutoLockEnabled, intent: SetLockyActivatedIntent()) {
                            Text("Locky")
                        }
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        Spacer()
                        Button(intent: LockMacNowIntent()) {
                            Label("Lock", systemImage: "lock.fill")
                        }
                        .controlSize(.small)
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    PhoneImage(data: entry.phoneImage, isConnected: state.isConnected)
                        .frame(height: 56)
                    Spacer()
                    Button(intent: LockMacNowIntent()) {
                        Image(systemName: "lock.fill")
                            .accessibilityLabel(Text("Lock"))
                    }
                    .buttonBorderShape(.circle)
                }
                Spacer(minLength: 0)
                PhoneInfo(state: state)
            }
        }
    }
}

/// Exact product image of the paired iPhone, dimmed when it is out of reach.
private struct PhoneImage: View {
    let data: Data?
    let isConnected: Bool

    var body: some View {
        Group {
            if let image = data.flatMap(NSImage.init(data:)) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "iphone")
                    .resizable()
                    .scaledToFit()
                    .fontWeight(.light)
            }
        }
        .opacity(isConnected ? 1 : 0.35)
        .accessibilityHidden(true)
    }
}

/// Name, connection, distance, battery and Locky's state.
private struct PhoneInfo: View {
    let state: MacWidgetState

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(state.phoneName ?? "iPhone")
                .font(.headline)
                .lineLimit(1)
            Label(connectionText, systemImage: state.isConnected ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.caption)
                .foregroundStyle(state.isConnected ? .primary : .secondary)
            HStack(spacing: 8) {
                if let level = state.batteryLevel {
                    Label("\(level)%", systemImage: level <= 20 ? "battery.25percent" : "battery.100percent")
                        .foregroundStyle(level <= 20 ? .red : .secondary)
                }
                Label(
                    state.isAutoLockEnabled ? "Locky on" : "Locky paused",
                    systemImage: state.isAutoLockEnabled ? "lock.shield.fill" : "pause.circle"
                )
                .foregroundStyle(state.isAutoLockEnabled ? .green : .orange)
            }
            .font(.caption2)
            .labelStyle(.titleAndIcon)
        }
    }

    private var connectionText: String {
        guard state.isConnected else { return String(localized: "Out of reach") }
        guard let distance = state.distance else { return String(localized: "Connected") }
        let formatted: String = Measurement(value: distance, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(1))))
        return String(localized: "About \(formatted) away")
    }
}

#Preview(as: .systemMedium) {
    PhoneStatusWidget()
} timeline: {
    PhoneStatusEntry.preview
}
