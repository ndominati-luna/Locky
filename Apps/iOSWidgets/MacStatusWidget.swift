import LockyKit
import SwiftUI
import WidgetKit

/// Home Screen and Lock Screen widget (replaces the former Today extension).
///
/// Small: the round Locky button of the app. Medium and large: the Mac over its wallpaper, its full
/// name, its connection, its automatic locking and the button. The live distance is in the Live Activity: widgets may only be
/// refreshed a few dozen times a day.
struct MacStatusWidget: Widget {
    let kind: String = "MacStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MacStatusProvider()) { entry in
            MacStatusWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    LockyWallpaperBackground(wallpaper: entry.wallpaper, isFaded: entry.snapshot.isOutOfReach)
                }
        }
        .configurationDisplayName("My Mac")
        .description("See whether your Mac is locked and lock or unlock it.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

/// Widget content for every family.
struct MacStatusWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: MacStatusEntry

    private var snapshot: LockySnapshot { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryCircular:
            AccessoryCircularView(snapshot: snapshot)
        case .accessoryRectangular:
            AccessoryRectangularView(snapshot: snapshot)
        case .accessoryInline:
            Label(inlineText, systemImage: snapshot.lockState.systemImage)
        case .systemLarge:
            LargeView(entry: entry)
                .foregroundStyle(.white)
                .fadedOutOfReach(snapshot.isOutOfReach)
        case .systemMedium:
            MediumView(entry: entry)
                .foregroundStyle(.white)
                .fadedOutOfReach(snapshot.isOutOfReach)
        default:
            SmallView(entry: entry)
                .foregroundStyle(.white)
                .fadedOutOfReach(snapshot.isOutOfReach)
        }
    }

    private var inlineText: String {
        guard let name = snapshot.macName else { return snapshot.localizedStatus }
        return "\(name) · \(snapshot.localizedStatus)"
    }
}

extension LockySnapshot {
    /// The round button can send its command.
    var isButtonEnabled: Bool {
        canSendCommands && !(lockState == .locked && unlockOnlyFromWatch)
    }

    /// Paired but not connected: the widget fades.
    var isOutOfReach: Bool {
        isPaired && !isConnected
    }
}

/// The name and the state of the Mac over the round button of the app.
private struct SmallView: View {
    let entry: MacStatusEntry

    var body: some View {
        VStack(spacing: 2) {
            MacNameText(name: entry.snapshot.macName ?? "Locky", font: .caption.bold())
            Text(entry.snapshot.localizedStatus)
                .font(.caption2)
                .lineLimit(1)
                .opacity(0.8)
            Spacer(minLength: 4)
            if entry.snapshot.isPaired {
                LockyRoundIntentButton(
                    lockState: entry.snapshot.lockState,
                    isEnabled: entry.snapshot.isButtonEnabled,
                    discSize: 58
                )
            } else {
                Text("Pair your Mac in the Locky app.")
                    .font(.caption2)
                    .opacity(0.8)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// The Mac and since when it is in its state, its name, connection and automatic locking, and the
/// round button with its title.
private struct MediumView: View {
    let entry: MacStatusEntry

    private var snapshot: LockySnapshot { entry.snapshot }

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 6) {
                WidgetMacImage(entry: entry)
                    .frame(maxHeight: 68)
                LockSinceLabel(snapshot: snapshot)
                    .font(.caption2)
                    .opacity(0.85)
            }
            .frame(width: 98)
            VStack(alignment: .leading, spacing: 6) {
                MacNameText(name: snapshot.macName ?? "Locky")
                VStack(alignment: .leading, spacing: 3) {
                    WidgetInfoRow(text: snapshot.connectionText, systemImage: snapshot.connectionSymbol)
                    WidgetInfoRow(text: snapshot.autoLockText, systemImage: snapshot.autoLockSymbol, lineLimit: 2)
                }
                .font(.caption2)
                .opacity(0.85)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if snapshot.isPaired {
                LockyRoundIntentButton(
                    lockState: snapshot.lockState,
                    isEnabled: snapshot.isButtonEnabled,
                    discSize: 46,
                    showsTitle: true,
                    titleFont: .caption2.bold()
                )
            }
        }
    }
}

/// Centered, in three groups: the name of the Mac and its connection, the Mac and its automatic
/// locking, the round button with its title. The lock state shows on the screen of the Mac and on
/// the button.
private struct LargeView: View {
    let entry: MacStatusEntry

    private var snapshot: LockySnapshot { entry.snapshot }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 4) {
                MacNameText(name: snapshot.macName ?? "Locky", font: .title3.bold())
                WidgetInfoRow(text: snapshot.connectionText, systemImage: snapshot.connectionSymbol)
                    .font(.subheadline)
                    .opacity(0.85)
            }
            Spacer(minLength: 8)
            VStack(spacing: 10) {
                WidgetMacImage(entry: entry)
                    .frame(maxHeight: 136)
                WidgetInfoRow(text: snapshot.autoLockText, systemImage: snapshot.autoLockSymbol)
                    .font(.subheadline)
                    .opacity(0.85)
            }
            Spacer(minLength: 8)
            if snapshot.isPaired {
                LockyRoundIntentButton(
                    lockState: snapshot.lockState,
                    isEnabled: snapshot.isButtonEnabled,
                    discSize: 52,
                    showsTitle: true
                )
            } else {
                Text("Pair your Mac in the Locky app.")
                    .font(.subheadline)
                    .opacity(0.85)
            }
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The Mac over its wallpaper, with the imitation of its lock screen while locked.
private struct WidgetMacImage: View {
    let entry: MacStatusEntry

    var body: some View {
        MacDeviceImage(
            frame: entry.deviceImage.flatMap(UIImage.init(data:)).map {
                MacFrame(image: $0, screen: entry.deviceScreen, hasWallpaper: true)
            },
            family: entry.snapshot.family,
            lockState: entry.snapshot.lockState,
            isConnected: entry.snapshot.isConnected,
            userPicture: entry.userPicture
        )
    }
}

private struct AccessoryCircularView: View {
    let snapshot: LockySnapshot

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if snapshot.isPaired, snapshot.canSendCommands {
                Group {
                    if snapshot.lockState == .locked {
                        Button(intent: UnlockMacIntent()) {
                            Image(systemName: "lock.open.fill")
                                .accessibilityLabel("Unlock")
                        }
                        .disabled(snapshot.unlockOnlyFromWatch)
                    } else {
                        Button(intent: LockMacIntent()) {
                            Image(systemName: "lock.fill")
                                .accessibilityLabel("Lock")
                        }
                    }
                }
                .font(.title2)
                .buttonStyle(.plain)
            } else {
                Image(systemName: snapshot.isConnected ? snapshot.lockState.systemImage : "antenna.radiowaves.left.and.right.slash")
                    .font(.title2)
            }
        }
        .widgetAccentable()
    }
}

private struct AccessoryRectangularView: View {
    let snapshot: LockySnapshot

    var body: some View {
        HStack {
            Image(systemName: snapshot.family.systemImage)
                .font(.title2)
                .widgetAccentable()
            VStack(alignment: .leading) {
                Text(snapshot.macName ?? "Locky")
                    .font(.headline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Label(snapshot.localizedStatus, systemImage: snapshot.lockState.systemImage)
                    .font(.caption)
            }
        }
    }
}

#Preview(as: .systemSmall) {
    MacStatusWidget()
} timeline: {
    MacStatusEntry.preview
}

#Preview(as: .systemMedium) {
    MacStatusWidget()
} timeline: {
    MacStatusEntry.preview
}

#Preview(as: .systemLarge) {
    MacStatusWidget()
} timeline: {
    MacStatusEntry.preview
}
