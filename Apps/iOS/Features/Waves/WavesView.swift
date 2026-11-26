import LockyKit
import SwiftUI

/// The measurements of the waves around the Mac, the one under way, or the invitation to make the
/// first one.
struct WavesView: View {
    @Environment(AppModel.self) private var model
    @State private var isCreating: Bool = false
    @State private var pendingDeletion: WaveScan?

    var body: some View {
        let waves: WaveScanCenter = model.waves
        let blocker: WaveScanBlocker? = model.waveScanBlocker
        Group {
            if waves.phase.run != nil {
                WaveScanProgressView(phase: waves.phase, isPeerMissing: waves.isPeerMissing, cancel: waves.cancel)
            } else if case let .failed(failure) = waves.phase {
                WaveScanFailureView(failure: failure) { waves.acknowledge() }
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
                    ScrollView {
                        WavesEmptyView { isCreating = true }
                            .containerRelativeFrame(.vertical)
                    }
                }
            } else {
                List {
                    ForEach(waves.scans) { scan in
                        NavigationLink(value: AppRoute.wave(id: scan.id)) {
                            WaveScanRow(scan: scan)
                        }
                        .swipeActions {
                            // Not destructive: the row stays until the deletion is confirmed.
                            Button("Delete", systemImage: "trash") {
                                pendingDeletion = scan
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Waves around")
        .scrollContentBackground(.hidden)
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.5, isFaded: !model.isConnected)
        .toolbar {
            if waves.phase.run == nil, !waves.scans.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("New measurement", systemImage: "plus") {
                        isCreating = true
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(waves.isMeasuring)
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
                Task { await waves.delete(scan) }
            }
        } message: { _ in
            Text("The measurement is deleted from your iPhone and your Mac.")
        }
        .task {
            await waves.refresh()
        }
        .refreshable {
            await waves.refresh()
        }
        .onChange(of: waves.phase) {
            if case let .finished(id) = waves.phase {
                waves.acknowledge()
                model.path.append(.wave(id: id))
            }
        }
    }
}

/// One measurement, pushed from the list; it leaves once deleted.
struct WaveScanScreen: View {
    let scanID: UUID
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var isConfirmingDeletion: Bool = false

    var body: some View {
        Group {
            if let scan = model.waves.scan(id: scanID) {
                WaveScanDetailView(scan: scan)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                isConfirmingDeletion = true
                            }
                        }
                    }
                    .confirmationDialog(
                        Text("Delete “\(scan.name)”?"),
                        isPresented: $isConfirmingDeletion,
                        titleVisibility: .visible
                    ) {
                        Button("Delete", role: .destructive) {
                            dismiss()
                            Task { await model.waves.delete(scan) }
                        }
                    } message: {
                        Text("The measurement is deleted from your iPhone and your Mac.")
                    }
            } else {
                Color.clear
                    .onAppear { dismiss() }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.5, isFaded: !model.isConnected)
    }
}

/// The measurement could not be kept.
private struct WaveScanFailureView: View {
    let failure: WaveScanFailure
    let acknowledge: () -> Void

    var body: some View {
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
            Button("OK", action: acknowledge)
                .buttonStyle(.glassProminent)
        }
    }
}
