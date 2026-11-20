import SwiftUI

/// The round Locky button of the original app, in Liquid Glass: the Locky bird on a red disc to
/// lock, on a blue one to unlock, ringed with its color. While the Mac answers, the ring turns
/// into a spinning arc, like in 2015. Shared by the iPhone and the Apple Watch.
struct LockyRoundButton: View {
    enum Mode: Equatable {
        case lock
        case unlock
    }

    let mode: Mode
    let isEnabled: Bool
    /// The command was sent: the Mac is locking or Locky is typing the password.
    let isWorking: Bool
    /// 88 on the iPhone; the ring and the spacing follow.
    var discSize: CGFloat = 88
    var titleFont: Font = .headline
    let action: () -> Void

    @State private var taps: Int = 0

    private var ringWidth: CGFloat {
        max(2, discSize * 0.045)
    }

    private var ringGap: CGFloat {
        discSize * 0.057
    }

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            VStack(spacing: discSize * 0.136) {
                ZStack {
                    Image(.lockyGlyph)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 2, y: 1)
                        .padding(discSize * 0.2)
                        .frame(width: discSize, height: discSize)
                        // Prominent glass, like the system's colored glass buttons: vivid color, glass edges
                        // and the gel reaction to touches.
                        .glassEffect(.regular.tint(tint).interactive(isEnabled && !isWorking), in: .circle)
                    LockyRoundButtonRing(color: tint, lineWidth: ringWidth, isSpinning: isWorking)
                        .frame(width: discSize + 2 * (ringGap + ringWidth), height: discSize + 2 * (ringGap + ringWidth))
                }
                Text(mode == .lock ? "Lock" : "Unlock")
                    .font(titleFont)
                    .lineLimit(1)
                    .foregroundStyle(isEnabled ? Color.primary : Color.secondary)
                    // The title gives way to the spinning ring, like the original button.
                    .opacity(isWorking ? 0 : 1)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // Busy: ignore taps but keep the color (disabling would fade the disc).
        .allowsHitTesting(!isWorking)
        .opacity(isEnabled ? 1 : 0.55)
        .animation(.smooth(duration: 0.35), value: mode)
        .animation(.smooth(duration: 0.25), value: isWorking)
        .sensoryFeedback(.impact(weight: .medium), trigger: taps)
        .accessibilityLabel(Text(mode == .lock ? "Lock your Mac" : "Unlock your Mac"))
    }

    /// The flat red and flat blue of the original button.
    private var tint: Color {
        guard isEnabled else { return .gray }
        return switch mode {
        case .lock: LockyTint.lock
        case .unlock: LockyTint.unlock
        }
    }
}

/// The ring around the button; a spinning arc while the command is in progress.
private struct LockyRoundButtonRing: View {
    let color: Color
    let lineWidth: CGFloat
    let isSpinning: Bool

    var body: some View {
        TimelineView(.animation(paused: !isSpinning)) { timeline in
            let turns: Double = timeline.date.timeIntervalSinceReferenceDate / 0.9
            Circle()
                .trim(from: 0, to: isSpinning ? 0.28 : 1)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(isSpinning ? (turns - turns.rounded(.down)) * 360 : -90))
        }
        .accessibilityHidden(true)
    }
}
