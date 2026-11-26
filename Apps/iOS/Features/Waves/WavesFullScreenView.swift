import LockyKit
import SwiftUI

/// The waves around on the large screen of an open iPhone Duo: a view of their own over the whole
/// screen, both pages included. The measurements line up as cards at the top; the one chosen spreads
/// below over the whole width, its cards in as many columns as fit, upright or held like a book.
struct WavesFullScreenView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var selection: UUID?
    @State private var isCreating: Bool = false
    @State private var pendingDeletion: WaveScan?

    var body: some View {
        let waves: WaveScanCenter = model.waves
        let blocker: WaveScanBlocker? = model.waveScanBlocker
        VStack(spacing: 0) {
            header(waves)
            content(waves)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            ImmersiveBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.5, isFaded: !model.isConnected)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $isCreating) {
            NewWaveScanView(blocker: blocker) { name in
                model.startWaveScan(name: name)
            }
        }
        .confirmationDialog(
            Text("Delete “\(pendingDeletion?.name ?? "")”?"),
            isPresented: .init(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible,
            presenting: pendingDeletion
        ) { scan in
            Button("Delete", role: .destructive) {
                if selection == scan.id {
                    selection = waves.scans.first { $0.id != scan.id }?.id
                }
                Task { await waves.delete(scan) }
            }
        } message: { _ in
            Text("The measurement is deleted from your iPhone and your Mac.")
        }
        .task {
            await waves.refresh()
            if selection == nil {
                selection = waves.scans.first?.id
            }
        }
        .onChange(of: waves.phase) {
            if case let .finished(id) = waves.phase {
                selection = id
                waves.acknowledge()
            }
        }
    }

    /// The title between the round buttons when it fits whole; otherwise the buttons above it, the
    /// new measurement as a round "+".
    private func header(_ waves: WaveScanCenter) -> some View {
        let canCreate: Bool = waves.phase.run == nil && !waves.scans.isEmpty
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) {
                closeButton(waves)
                // Whole, or this layout does not fit.
                title
                    .fixedSize(horizontal: true, vertical: false)
                Spacer(minLength: 16)
                if canCreate {
                    Button("New measurement", systemImage: "plus") {
                        isCreating = true
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    closeButton(waves)
                    Spacer()
                    if canCreate {
                        Button("New measurement", systemImage: "plus") {
                            isCreating = true
                        }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.large)
                    }
                }
                title
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var title: some View {
        Text("Waves around")
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .lineLimit(1)
    }

    private func closeButton(_ waves: WaveScanCenter) -> some View {
        Button("Close", systemImage: "xmark") {
            dismiss()
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        // Closing in the middle would leave the measurement without anything to show it.
        .disabled(waves.isMeasuring)
    }

    @ViewBuilder
    private func content(_ waves: WaveScanCenter) -> some View {
        if waves.phase.run != nil {
            WaveScanProgressView(phase: waves.phase, isPeerMissing: waves.isPeerMissing, cancel: waves.cancel)
        } else if case let .failed(failure) = waves.phase {
            ContentUnavailableView {
                Label("Measurement not saved", systemImage: "icloud.slash")
            } description: {
                switch failure {
                case .iCloudUnavailable:
                    Text("Sign in to iCloud on your iPhone with the same Apple Account as your Mac to keep your measurements.")
                case .notSaved:
                    Text("iCloud did not take it. Try again in a moment.")
                }
            } actions: {
                Button("OK") { waves.acknowledge() }
                    .buttonStyle(.glassProminent)
            }
        } else if !waves.isCloudAvailable {
            ContentUnavailableView(
                "iCloud unavailable",
                systemImage: "icloud.slash",
                description: Text("Sign in to iCloud on your iPhone and your Mac with the same Apple Account to keep your measurements.")
            )
        } else if waves.scans.isEmpty {
            if waves.isLoading, !waves.hasLoaded {
                ProgressView()
            } else {
                WavesEmptyView { isCreating = true }
            }
        } else {
            VStack(spacing: 0) {
                WaveScanStrip(scans: waves.scans, selection: $selection) { scan in
                    pendingDeletion = scan
                }
                if let scan = waves.scan(id: selection ?? UUID()) ?? waves.scans.first {
                    WaveScanDetailView(scan: scan) {
                        pendingDeletion = scan
                    }
                    .id(scan.id)
                    .transition(.opacity)
                }
            }
            .animation(.smooth, value: selection)
        }
    }
}

/// A measurement in the strip: its verdict, its name, its verdict in words and when, on two lines
/// whatever the length of the date.
private struct WaveScanCard: View {
    let scan: WaveScan

    var body: some View {
        let impact: WaveImpact = scan.impact
        HStack(spacing: 12) {
            ImpactGauge(score: impact.score, level: impact.level, isCompact: true)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: scan.name.isEmpty ? String(localized: "Measurement") : scan.name)
                    .font(.headline)
                HStack(spacing: 4) {
                    if !impact.factors.isEmpty {
                        Text(impact.level.title)
                            .foregroundStyle(impact.level.color)
                            .fontWeight(.semibold)
                        Text(verbatim: "·")
                            .foregroundStyle(.secondary)
                    }
                    Text(scan.date, format: .dateTime.day().month().hour().minute())
                        .foregroundStyle(.secondary)
                }
                .font(.subheadline)
            }
            .lineLimit(1)
        }
        .frame(width: 250, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The measurements side by side, the one shown highlighted.
private struct WaveScanStrip: View {
    let scans: [WaveScan]
    @Binding var selection: UUID?
    let delete: (WaveScan) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(scans) { scan in
                    let isSelected: Bool = scan.id == (selection ?? scans.first?.id)
                    Button {
                        selection = scan.id
                    } label: {
                        WaveScanCard(scan: scan)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(.rect(cornerRadius: 22))
                    }
                    .buttonStyle(.plain)
                    .glassEffect(isSelected ? .regular.tint(Color.accentColor.opacity(0.35)).interactive() : .regular.interactive(), in: .rect(cornerRadius: 22))
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            delete(scan)
                        }
                    }
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 8)
        }
        .scrollIndicators(.hidden)
    }
}
