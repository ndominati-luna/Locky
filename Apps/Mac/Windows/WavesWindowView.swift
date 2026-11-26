import LockyKit
import SwiftUI

/// The measurements of the waves around the Mac: the list on the side, the measurement chosen (or
/// the one under way) on the right.
struct WavesWindowView: View {
    @Environment(MacAppModel.self) private var model
    @State private var selection: UUID?
    @State private var isCreating: Bool = false
    @State private var pendingDeletion: WaveScan?
    @State private var startFailed: Bool = false

    var body: some View {
        let waves: WaveScanCenter = model.waves
        let blocker: WaveScanBlocker? = model.waveScanBlocker
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(waves.scans) { scan in
                    WaveScanRow(scan: scan)
                        .tag(scan.id)
                        .contextMenu {
                            Button("Delete…", role: .destructive) {
                                pendingDeletion = scan
                            }
                        }
                }
            }
            .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
            .overlay {
                if waves.isLoading, waves.scans.isEmpty {
                    ProgressView()
                }
            }
            .onDeleteCommand {
                pendingDeletion = selectedScan
            }
            .toolbar {
                ToolbarItem {
                    Button("New measurement", systemImage: "plus") {
                        isCreating = true
                    }
                    .disabled(waves.phase.run != nil)
                    .help(Text("Measure the waves around your Mac"))
                }
            }
        } detail: {
            detail(waves)
        }
        .frame(minWidth: 860, minHeight: 620)
        .sheet(isPresented: $isCreating) {
            NewWaveScanView(blocker: blocker) { name in
                if !model.startWaveScan(name: name) {
                    startFailed = true
                }
            }
            .onAppear {
                model.prepareWaveScan()
            }
        }
        .confirmationDialog(
            Text("Delete “\(pendingDeletion?.name ?? "")”?"),
            isPresented: .init(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            presenting: pendingDeletion
        ) { scan in
            Button("Delete", role: .destructive) {
                if selection == scan.id {
                    selection = nil
                }
                Task { await waves.delete(scan) }
            }
        } message: { _ in
            Text("The measurement is deleted from your Mac and your iPhone.")
        }
        .alert("The measurement could not start", isPresented: $startFailed) {
            Button("OK") {}
        } message: {
            Text("Check that your iPhone is next to your Mac, with Locky open on it.")
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

    private var selectedScan: WaveScan? {
        selection.flatMap(model.waves.scan(id:))
    }

    @ViewBuilder
    private func detail(_ waves: WaveScanCenter) -> some View {
        if waves.phase.run != nil {
            WaveScanProgressView(phase: waves.phase, isPeerMissing: waves.isPeerMissing, cancel: waves.cancel)
        } else if case let .failed(failure) = waves.phase {
            ContentUnavailableView {
                Label("Measurement not saved", systemImage: "icloud.slash")
            } description: {
                switch failure {
                case .iCloudUnavailable:
                    Text("Sign in to iCloud on your Mac with the same Apple Account as your iPhone to keep your measurements.")
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
                description: Text("Sign in to iCloud on your Mac and your iPhone with the same Apple Account to keep your measurements.")
            )
        } else if let scan = selectedScan {
            WaveScanDetailView(scan: scan) {
                pendingDeletion = scan
            }
            .id(scan.id)
        } else if waves.scans.isEmpty {
            WavesEmptyView { isCreating = true }
        } else {
            ContentUnavailableView("Choose a measurement", systemImage: "dot.radiowaves.left.and.right")
        }
    }
}
