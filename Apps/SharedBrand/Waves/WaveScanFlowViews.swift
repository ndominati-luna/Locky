import LockyKit
import SwiftUI

// MARK: - New measurement

/// Names a measurement before it starts, says how to place the devices and what may happen meanwhile.
struct NewWaveScanView: View {
    /// Why it cannot start, `nil` when it can.
    let blocker: WaveScanBlocker?
    let start: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var isNameFocused: Bool

    private static let suggestions: [LocalizedStringResource] = ["Home", "Office", "Bedroom", "Café"]

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name, prompt: Text("Home, office, café…"))
                        .focused($isNameFocused)
                        .onSubmit(startIfPossible)
                        .onChange(of: name) {
                            if name.count > WaveScan.maximumNameLength {
                                name = String(name.prefix(WaveScan.maximumNameLength))
                            }
                        }
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(Self.suggestions, id: \.key) { suggestion in
                                Button(String(localized: suggestion)) {
                                    name = String(localized: suggestion)
                                }
                                .buttonStyle(.bordered)
                                .buttonBorderShape(.capsule)
                                .controlSize(.small)
                            }
                        }
                    }
                    .scrollIndicators(.hidden)
                } header: {
                    Text("Where are you?")
                } footer: {
                    Text("Name it after the place, to find it among your measurements.")
                }
                Section {
                    Label("Lay your iPhone next to your Mac and leave both still for 20 seconds.", systemImage: "laptopcomputer.and.iphone")
                    Label("Meanwhile, the Wi-Fi of your Mac may pause for a moment and Bluetooth headphones may stutter. Locky neither locks nor unlocks until it is over.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
                .font(.callout)
                if let blocker {
                    Section {
                        Label(blocker.message, systemImage: "xmark.octagon")
                            .foregroundStyle(.red)
                            .font(.callout)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New measurement")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start", action: startIfPossible)
                        .disabled(blocker != nil || trimmedName.isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 470)
        #else
        .presentationDetents([.large])
        #endif
    }

    private func startIfPossible() {
        guard blocker == nil, !trimmedName.isEmpty else { return }
        start(trimmedName)
        dismiss()
    }
}

// MARK: - Measuring

/// The measurement under way: a beam sweeps while both devices listen, then the parts go to iCloud.
struct WaveScanProgressView: View {
    let phase: WaveScanPhase
    /// The other device does not take part (Locky left the screen of the iPhone…).
    let isPeerMissing: Bool
    let cancel: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ZStack {
                BluetoothRadarView(mac: [], phone: [], showsCenter: false)
                    .frame(width: 220, height: 220)
                countdown
            }
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 380)
            }
            HStack(spacing: 10) {
                ForEach(WaveListenItem.allCases, id: \.self) { item in
                    WaveListenChip(item: item, isDone: !isMeasuring)
                }
            }
            if isPeerMissing {
                Label(peerMissingMessage, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
            if isMeasuring {
                Button("Cancel", role: .cancel, action: cancel)
                    .buttonStyle(.glass)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isMeasuring: Bool {
        if case .measuring = phase { true } else { false }
    }

    @ViewBuilder
    private var countdown: some View {
        if case let .measuring(run) = phase {
            TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
                let remaining: Int = max(0, Int(run.endsAt.timeIntervalSince(timeline.date).rounded(.up)))
                Text(verbatim: "\(remaining)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.smooth, value: remaining)
            }
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }

    private var title: String {
        switch phase {
        case let .measuring(run): String(localized: "Measuring “\(run.name)”")
        case let .saving(run): String(localized: "Saving “\(run.name)”")
        default: ""
        }
    }

    private var subtitle: LocalizedStringKey {
        if isMeasuring {
            "Leave your iPhone next to your Mac. Locky neither locks nor unlocks meanwhile."
        } else {
            "Both parts of the measurement go to iCloud, sealed with the key of your pairing."
        }
    }

    private var peerMissingMessage: LocalizedStringKey {
        #if os(macOS)
        "Your iPhone does not take part: open Locky on it next time to measure everything."
        #else
        "Your Mac does not take part: what only it hears will be missing."
        #endif
    }
}

/// What both devices listen to, shown while measuring.
enum WaveListenItem: CaseIterable {
    case wifi
    case bluetooth
    case sound
    case magneticField
    case link

    var systemImage: String {
        switch self {
        case .wifi: "wifi"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .sound: "waveform"
        case .magneticField: "location.north.line"
        case .link: "link"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .wifi: "Wi-Fi"
        case .bluetooth: "Bluetooth"
        case .sound: "Sound"
        case .magneticField: "Magnetism"
        case .link: "Link"
        }
    }
}

private struct WaveListenChip: View {
    let item: WaveListenItem
    let isDone: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: isDone ? "checkmark" : item.systemImage)
                .font(.callout.weight(.semibold))
                .frame(width: 40, height: 40)
                .glassEffect(.regular.tint(isDone ? Color.green.opacity(0.5) : Color.clear), in: .circle)
                .symbolEffect(.pulse, options: .repeating, isActive: !isDone && !reduceMotion)
                .contentTransition(.symbolEffect(.replace))
            Text(item.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - List

/// A measurement in a list: its name, when, and its verdict for Locky.
struct WaveScanRow: View {
    let scan: WaveScan

    var body: some View {
        let impact: WaveImpact = scan.impact
        HStack(spacing: 12) {
            ImpactGauge(score: impact.score, level: impact.level, isCompact: true)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: scan.name.isEmpty ? String(localized: "Measurement") : scan.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(scan.date, format: .dateTime.day().month().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            if !impact.factors.isEmpty {
                Text(impact.level.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(impact.level.color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
