import LockyKit
import SwiftUI

/// Second page of an unfolded iPhone Duo: what happens on the Mac, in glass cards like widgets.
/// The Mac streams its state only while this page is on screen. Out of reach, a single message
/// explains why, and only the break-in reports remain.
struct MacDashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.screenFold) private var fold
    @State private var isOnScreen: Bool = false

    var body: some View {
        Group {
            if model.isConnected {
                MacDashboardCards()
            } else {
                MacUnreachableView()
                    .transition(.opacity)
            }
        }
        .animation(.smooth(duration: 0.4), value: model.isConnected)
        .navigationTitle("Your Mac")
        // Half open like a laptop, the page is only half as tall: no room for a large title.
        .navigationBarTitleDisplayMode(fold?.orientation == .horizontal ? .inline : .automatic)
        // Over the shared wallpaper, like the Mac on the first page.
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                MainMenu()
            }
        }
        .immersivePageBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.45)
        .onAppear {
            isOnScreen = true
            updateStreaming()
        }
        .onDisappear {
            isOnScreen = false
            updateStreaming()
        }
        .onChange(of: scenePhase) {
            updateStreaming()
        }
    }

    private func updateStreaming() {
        model.setDashboardVisible(isOnScreen && scenePhase == .active)
    }
}

/// The glass cards: music, activity of the Mac, the Mac itself and Locky.
private struct MacDashboardCards: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 18) {
                VStack(spacing: 14) {
                    NowPlayingCard()
                    Group {
                        if let metrics = model.macMetrics {
                            MacMetricsGrid(metrics: metrics)
                        } else {
                            // Waiting for the first measures: the shape of the cards, without values.
                            MacMetricsGrid(metrics: .placeholder)
                                .redacted(reason: .placeholder)
                                .overlay {
                                    Text("Reading the activity of your Mac…")
                                        .font(.footnote.weight(.medium))
                                        .foregroundStyle(Color.secondary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .glassEffect(.regular, in: .capsule)
                                }
                        }
                    }
                    .animation(.smooth, value: model.macMetrics == nil)
                    MacSummaryCard()
                    LockySummaryCard()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
    }
}

extension MacMetrics {
    /// Shape of the cards while the first measures are on their way.
    static var placeholder: MacMetrics {
        .init(
            cpuUsage: 0.3,
            coreCount: 8,
            memoryUsed: 8_000_000_000,
            memoryTotal: 16_000_000_000,
            memoryPressure: .normal,
            diskAvailable: 200_000_000_000,
            diskTotal: 500_000_000_000,
            diskName: nil,
            battery: .init(level: 80, isCharging: false, isOnPower: true, minutesRemaining: nil),
            thermalState: .nominal,
            bootDate: .now,
            outputVolume: nil,
            isMuted: false,
            date: .now
        )
    }
}
