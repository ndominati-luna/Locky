import LockyKit
import SwiftUI

/// The paired Mac, displayed like a lock screen over its own blurred wallpaper.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.screenFold) private var fold
    /// Side by side when the available space is wider than tall (landscape, top page of a Duo
    /// turned like a laptop), stacked otherwise (portrait, a page of an unfolded Duo).
    @State private var isWide: Bool = false
    /// The page of the Mac, in a sheet where it has no page of its own (button of ``MainToolbar``).
    @State private var isMacPanelPresented: Bool = Self.showsMacPanelAtLaunch

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 24) {
                    MacShowcase()
                    VStack(spacing: 24) {
                        LockStateHeader()
                        Spacer()
                        HomeActions()
                    }
                    // Room for "slide to unlock" in every language; the Mac takes what is left.
                    .frame(minWidth: 320, maxWidth: 440)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 20) {
                    LockStateHeader()
                    Spacer(minLength: 0)
                    MacShowcase()
                    Spacer(minLength: 0)
                    HomeActions()
                }
                .padding(.horizontal, 24)
                .padding(.vertical)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height * 1.1 } action: { isWide = $0 }
        .background {
            // Unfolded, both pages share the background of the main view.
            if fold == nil {
                ImmersiveBackground(wallpaper: model.visuals.backgroundWallpaper, intensity: 0.3, isFaded: !model.isConnected)
                    .animation(.smooth(duration: 0.6), value: model.visuals.backgroundWallpaper)
            }
        }
        .toolbar {
            // Unfolded, the Mac has its own page instead.
            MainToolbar(openMacPanel: fold == nil ? { isMacPanelPresented = true } : nil)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(duration: 0.5), value: model.lockState)
        .sheet(isPresented: $isMacPanelPresented) {
            MacPanelSheet()
        }
        // A break-in notification opens the reports on the main screen: out of the way.
        .onChange(of: model.path) {
            isMacPanelPresented = false
        }
    }

    private static var showsMacPanelAtLaunch: Bool {
        #if DEBUG
        DemoMode.showsMacPanel
        #else
        false
        #endif
    }
}

/// Big lock state, time since the last change and connection, like the clock of a lock screen.
private struct LockStateHeader: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        // The chip stands apart from the state, like the date above the clock of a lock screen.
        VStack(spacing: 18) {
            ConnectionChip()
            // Last known state: faded while the Mac is out of reach.
            VStack(spacing: 8) {
                Text(model.lockState == .locked ? "Locked" : model.lockState == .unlocked ? "Unlocked" : "Locky")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .imageScale(.large)
                    .contentTransition(.numericText())
                if let date = model.macStatus?.lockStateDate, date > .distantPast, model.lockState != .unknown {
                    Text(sinceText(date))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }
            .fadedWhileOutOfReach(!model.isConnected)
        }
        .foregroundStyle(.primary)
        .multilineTextAlignment(.center)
        .padding(.top, 8)
    }

    private func sinceText(_ date: Date) -> String {
        guard Date.now.timeIntervalSince(date) >= 60 else { return String(localized: "Just now") }
        return String(localized: "Since \(date.formatted(.relative(presentation: .named)))")
    }
}

/// "Connected · about 1.3 m" or why the Mac cannot be reached.
private struct ConnectionChip: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .glassEffect(.regular, in: .capsule)
            .symbolEffect(.variableColor.iterative, options: .repeating, isActive: model.session.connection == .searching)
    }

    private var symbol: String {
        switch model.session.connection {
        case .connected: model.isMoving ? "figure.walk" : "iphone.radiowaves.left.and.right"
        case .connecting: "lock.shield"
        case .searching: "dot.radiowaves.left.and.right"
        case .bluetoothOff, .unauthorized, .unsupported: "exclamationmark.triangle"
        }
    }

    private var text: String {
        model.connectionSummary
    }
}

/// The Mac floating over its wallpaper. It can be pulled around and always springs back to the
/// center.
private struct MacShowcase: View {
    @Environment(AppModel.self) private var model
    @State private var drag: CGSize = .zero

    var body: some View {
        VStack(spacing: 14) {
            MacDeviceImage(
                frame: model.macFrame,
                family: model.macStatus?.family ?? .unknown,
                wallpaper: model.visuals.wallpaperImage,
                lockState: model.lockState,
                isConnected: model.isConnected,
                userPicture: model.visuals.userPicture,
                userName: model.macStatus?.userName,
                isUnlocking: model.isUnlocking
            )
            .foregroundStyle(.primary)
            // Grows with the large screen of an unfolded iPhone Duo held upright.
            .frame(maxWidth: 560, maxHeight: 380)
            .shadow(color: .black.opacity(0.45), radius: 24, y: 14 + drag.height * 0.1)
            .offset(drag)
            .rotation3DEffect(.degrees(Double(drag.width) * 0.08), axis: (x: 0, y: 1, z: 0))
            .rotation3DEffect(.degrees(Double(-drag.height) * 0.08), axis: (x: 1, y: 0, z: 0))
            .gesture(rubberBand)

            VStack(spacing: 4) {
                Text(model.macName)
                    .font(.title2.bold())
                if let productName = model.macStatus?.productName, productName != model.macName {
                    Text(productName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .fadedWhileOutOfReach(!model.isConnected)
    }

    /// The further you pull, the harder it resists; released, it bounces back to the center.
    private var rubberBand: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                drag = .init(width: resist(value.translation.width), height: resist(value.translation.height))
            }
            .onEnded { _ in
                withAnimation(.spring(duration: 0.6, bounce: 0.55)) { drag = .zero }
            }
    }

    private func resist(_ translation: CGFloat) -> CGFloat {
        let limit: CGFloat = 90
        return limit * translation / (abs(translation) + limit)
    }
}

/// The round Locky button and the hints below it.
private struct HomeActions: View {
    @Environment(AppModel.self) private var model
    /// Tapped: waiting for the Mac to report its new state.
    @State private var isWaiting: Bool = false
    /// Identifies the last tap, so an older timeout never stops a newer wait.
    @State private var attempt: Int = 0

    var body: some View {
        VStack(spacing: 14) {
            LockyRoundButton(
                mode: isLocked ? .unlock : .lock,
                isEnabled: model.isConnected && !(isLocked && model.preferences.unlockOnlyFromWatch),
                isWorking: isWaiting || model.isUnlocking,
                action: perform
            )
            if let hint {
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .onChange(of: model.lockState) {
            isWaiting = false
        }
        .onChange(of: model.isConnected) {
            isWaiting = false
        }
    }

    private var isLocked: Bool {
        model.lockState == .locked
    }

    private var hint: LocalizedStringKey? {
        if isLocked, model.preferences.unlockOnlyFromWatch {
            return "Your Mac can only be unlocked from your Apple Watch."
        }
        if let status = model.macStatus, !status.isAutoLockEnabled, model.isConnected {
            return "Automatic locking is paused. Turn it back on in Settings or in the Locky menu on your Mac."
        }
        switch model.session.connection {
        case .searching: return "Make sure Locky is running on your Mac and Bluetooth is on."
        case .bluetoothOff: return "Turn on Bluetooth so Locky can reach your Mac."
        case .unauthorized: return "Locky needs Bluetooth access to reach your Mac."
        default: return nil
        }
    }

    private func perform() {
        attempt += 1
        let current: Int = attempt
        isWaiting = true
        Task {
            guard await model.perform(.toggle, origin: .app) else {
                isWaiting = false
                return
            }
            // Never spin forever if the Mac does not answer.
            try? await Task.sleep(for: .seconds(10))
            if attempt == current {
                isWaiting = false
            }
        }
    }
}

extension View {
    /// What only makes sense with the Mac in reach (its state, its picture) fades while it is not;
    /// the connection chip and the hints explaining why stay clear.
    func fadedWhileOutOfReach(_ isFaded: Bool) -> some View {
        opacity(isFaded ? 0.45 : 1)
            .animation(.smooth(duration: 0.6), value: isFaded)
    }
}
