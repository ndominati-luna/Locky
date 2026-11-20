import LockyKit
import SwiftUI

/// Main (and only) screen of the Watch app: the Mac over its blurred wallpaper, like the other
/// apps, its state and the round Locky button, all on one screen without scrolling.
struct WatchHomeView: View {
    @Environment(WatchModel.self) private var model

    var body: some View {
        @Bindable var model = model
        Group {
            if model.snapshot.isPaired {
                WatchMacPanel()
            } else {
                Text("Pair your Mac from the Locky app on your iPhone.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            LockyWallpaperBackground(
                wallpaper: model.wallpaper,
                isFaded: model.snapshot.isPaired && !model.snapshot.isConnected
            )
            .ignoresSafeArea()
        }
        .alert(
            "Locky",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }
}

/// The paired Mac: its picture takes the room the state and the button leave, so everything fits
/// on every Watch size.
private struct WatchMacPanel: View {
    @Environment(WatchModel.self) private var model

    private var snapshot: LockySnapshot {
        model.snapshot
    }

    var body: some View {
        VStack(spacing: 6) {
            MacDeviceImage(
                frame: model.macFrame,
                family: snapshot.family,
                wallpaper: model.wallpaperImage,
                lockState: snapshot.lockState,
                isConnected: snapshot.isConnected
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(-1)

            // The state in plain text, like the iPhone and the widgets: the colors belong to the button.
            VStack(spacing: 0) {
                Text(snapshot.localizedStatus)
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if snapshot.isConnected, let date = snapshot.lockStateDate, snapshot.lockState != .unknown {
                    SinceText(date: date)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            LockyRoundButton(
                mode: snapshot.lockState == .locked ? .unlock : .lock,
                isEnabled: snapshot.canSendCommands,
                isWorking: model.isSending,
                discSize: 40,
                titleFont: .footnote.bold(),
                action: model.toggle
            )
            .handGestureShortcut(.primaryAction)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
        .frame(maxHeight: .infinity)
        // The title of the button can go down to the bottom edge (it is centered, away from the
        // rounded corners): the Mac gets that room.
        .ignoresSafeArea(.container, edges: .bottom)
    }
}
