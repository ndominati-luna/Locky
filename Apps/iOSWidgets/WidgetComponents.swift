import LockyKit
import SwiftUI
import WidgetKit

/// The round Locky button of the app (bird on a red disc to lock, on a blue one to unlock, ringed
/// with its color), as an App Intent button for widgets and the Live Activity.
struct LockyRoundIntentButton: View {
    let lockState: LockState
    let isEnabled: Bool
    var discSize: CGFloat = 60
    var showsTitle: Bool = false
    var titleFont: Font = .caption.bold()

    private var isLocked: Bool {
        lockState == .locked
    }

    var body: some View {
        Group {
            if isLocked {
                Button(intent: UnlockMacIntent()) { label }
            } else {
                Button(intent: LockMacIntent()) { label }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var label: some View {
        VStack(spacing: 4) {
            LockyDisc(tint: isEnabled ? LockyTint.color(for: isLocked ? .locked : .unlocked) : .gray, discSize: discSize)
            if showsTitle {
                Text(isLocked ? "Unlock" : "Lock")
                    .font(titleFont)
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .opacity(isEnabled ? 1 : 0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(isLocked ? "Unlock your Mac" : "Lock your Mac"))
    }
}

/// The disc of the round button: the Locky bird on its color, a thin glass edge and the ring.
struct LockyDisc: View {
    let tint: Color
    let discSize: CGFloat

    var body: some View {
        let ringWidth: CGFloat = max(2, discSize * 0.045)
        let ringGap: CGFloat = discSize * 0.055
        ZStack {
            Circle()
                .fill(tint.gradient)
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                }
                .shadow(color: tint.opacity(0.45), radius: discSize * 0.1, y: discSize * 0.03)
                .frame(width: discSize, height: discSize)
            Image(.lockyGlyph)
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.2), radius: 1.5, y: 1)
                .padding(discSize * 0.2)
                .frame(width: discSize, height: discSize)
                .widgetAccentable()
            Circle()
                .stroke(tint, lineWidth: ringWidth)
                .frame(width: discSize + 2 * (ringGap + ringWidth), height: discSize + 2 * (ringGap + ringWidth))
        }
        .frame(width: discSize + 2 * (ringGap + ringWidth), height: discSize + 2 * (ringGap + ringWidth))
    }
}

extension View {
    /// Fades the content of a widget while the Mac is out of reach.
    func fadedOutOfReach(_ isFaded: Bool) -> some View {
        opacity(isFaded ? 0.55 : 1)
    }
}

/// The name of the Mac on up to two lines, shrinking a little rather than being cut.
struct MacNameText: View {
    let name: String
    var font: Font = .headline
    var lineLimit: Int = 2

    var body: some View {
        Text(name)
            .font(font)
            .lineLimit(lineLimit)
            .minimumScaleFactor(0.7)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// "🔒 12 minutes ago": since when the Mac is in its state (nothing while out of reach).
struct LockSinceLabel: View {
    let snapshot: LockySnapshot

    var body: some View {
        if snapshot.isConnected, snapshot.lockState != .unknown, let date = snapshot.lockStateDate {
            Label {
                SinceText(date: date)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            } icon: {
                Image(systemName: snapshot.lockState.systemImage)
            }
            .labelStyle(CompactLabelStyle())
        }
    }
}

/// Symbol and title close together.
private struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
            configuration.title
        }
    }
}

/// A small line of information with its symbol.
struct WidgetInfoRow: View {
    let text: String
    let systemImage: String
    var lineLimit: Int = 1

    var body: some View {
        Label {
            Text(text)
                .lineLimit(lineLimit)
                .minimumScaleFactor(0.8)
                .fixedSize(horizontal: false, vertical: lineLimit > 1)
        } icon: {
            Image(systemName: systemImage)
                .frame(width: 18)
        }
    }
}

extension LockySnapshot {
    /// "Connected" or "Out of reach".
    var connectionText: String {
        isConnected ? String(localized: "Connected") : String(localized: "Out of reach")
    }

    var connectionSymbol: String {
        isConnected ? "dot.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash"
    }

    var autoLockSymbol: String {
        isAutoLockEnabled ? "figure.walk.departure" : "pause.circle"
    }

    /// "Locks beyond 1.5 m" or "Automatic locking paused".
    var autoLockText: String {
        guard isAutoLockEnabled else { return String(localized: "Automatic locking paused") }
        guard let lockDistance else { return String(localized: "Automatic locking on") }
        let formatted: String = Measurement(value: lockDistance, unit: UnitLength.meters).formatted(.lockyDistance)
        return String(localized: "Locks beyond \(formatted)")
    }
}
