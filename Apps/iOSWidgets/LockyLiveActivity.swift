import ActivityKit
import LockyKit
import SwiftUI
import WidgetKit

/// The Locky Live Activity.
///
/// - Dynamic Island, compact: the Locky logo, then the white padlock of the state (open or closed)
///   and the distance with its unit, in the color of the distance gauge where the iPhone is (the
///   padlock alone on an iPhone Duo).
/// - Lock Screen and expanded island: the Mac over its blurred wallpaper (with the imitation of its
///   lock screen when locked), the distance gauge up to the padlock at the lock distance, and the
///   round Locky button with its title.
struct LockyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LockyActivityAttributes.self) { context in
            LockyActivityLockScreenView(attributes: context.attributes, state: context.state)
                .activityBackgroundTint(.black.opacity(0.35))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state: LockyActivityAttributes.ContentState = context.state
            return DynamicIsland {
                // Everything below the camera, over the whole width: the Mac, its texts and the
                // button in one row with their tops aligned, then the gauge.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            ActivityExpandedHeader(attributes: context.attributes, state: state)
                            LockyRoundIntentButton(
                                lockState: state.lockState,
                                isEnabled: state.isButtonEnabled,
                                discSize: 34,
                                showsTitle: true,
                                titleFont: .caption2.bold()
                            )
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            ActivityDistanceGauge(state: state)
                            ActivityDistanceCaption(state: state)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .fadedOutOfReach(!state.isConnected)
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                Image(.lockyGlyph)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(state.isConnected ? Color.white : Color.gray)
                    .accessibilityLabel(Text(verbatim: "Locky"))
            } compactTrailing: {
                ActivityCompactStatus(state: state)
            } minimal: {
                ActivityPadlock(state: state)
                    .frame(width: 24, height: 24)
            }
            // Not the color of the distance: the island would be redrawn at every distance update
            // (every 2 seconds), even on an iPhone Duo where it shows no distance, and its icons
            // would jump.
            .keylineTint(ActivityTint.lockState(state))
        }
    }
}

/// Colors of the activity.
enum ActivityTint {
    /// The padlock: white like the Locky logo facing it (its shape tells the state), gray out of
    /// reach. The color is left to the distance next to it.
    static func lockState(_ state: LockyActivityAttributes.ContentState) -> Color {
        state.isConnected ? .white : .gray
    }

    /// The color of the distance gauge where the iPhone is: blue near the Mac, turning red up to the
    /// lock distance and beyond. Faded like the gauge while automatic locking is paused, gray out
    /// of reach.
    static func distance(_ state: LockyActivityAttributes.ContentState) -> Color {
        guard state.isConnected else { return .gray }
        let fraction: Double = state.distance.map { $0 / max(state.lockDistance, 0.1) } ?? 0
        let color: Color = ActivityDistanceGauge.color(at: fraction)
        return state.isAutoLockEnabled ? color : color.opacity(0.5)
    }
}

/// Lock Screen presentation (and banner on devices without Dynamic Island).
struct LockyActivityLockScreenView: View {
    let attributes: LockyActivityAttributes
    let state: LockyActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            ActivityMacImage(family: attributes.family, state: state)
                .frame(width: 92, height: 70)
            VStack(alignment: .leading, spacing: 5) {
                MacNameText(name: attributes.macName, font: .headline, lineLimit: 1)
                ActivityStateLine(state: state)
                    .font(.caption)
                    .opacity(0.9)
                ActivityDistanceGauge(state: state)
                    .padding(.top, 2)
                ActivityDistanceCaption(state: state)
                    .font(.caption2)
                    .opacity(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            LockyRoundIntentButton(
                lockState: state.lockState,
                isEnabled: state.isButtonEnabled,
                discSize: 44,
                showsTitle: true,
                titleFont: .caption2.bold()
            )
        }
        .fadedOutOfReach(!state.isConnected)
        .padding(16)
        .foregroundStyle(.white)
        .background {
            LockyWallpaperBackground(wallpaper: ActivityImages.wallpaper, blur: 14, isFaded: !state.isConnected)
        }
    }
}

/// Expanded island: the Mac, then its name and state aligned on their left, level with the top of
/// the Mac.
private struct ActivityExpandedHeader: View {
    let attributes: LockyActivityAttributes
    let state: LockyActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ActivityMacImage(family: attributes.family, state: state)
                .frame(width: 64, height: 48)
            VStack(alignment: .leading, spacing: 2) {
                MacNameText(name: attributes.macName, font: .headline)
                ActivityStateLine(state: state)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Compact island, right: the padlock of the state of the Mac and the distance in the color of the
/// gauge (a crossed antenna out of reach). The padlock alone on an iPhone Duo, whose upright island
/// clips the sides (see ``DeviceModel``); it turns gray out of reach.
private struct ActivityCompactStatus: View {
    let state: LockyActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 2) {
            if DeviceModel.hasUprightIsland {
                // Same square as the Locky logo facing it: the open padlock is wider than the closed
                // one, and the island would resize, shifting both icons, at every change.
                ActivityPadlock(state: state)
                    .frame(width: 24, height: 24)
            } else {
                ActivityPadlock(state: state)
                if state.isConnected {
                    if let distance = state.distance {
                        // With its unit ("1,3 m"): only the upright island of the Duo lacks the room.
                        Text(Measurement(value: distance, unit: UnitLength.meters), format: .lockyDistance)
                            .monospacedDigit()
                            .lineLimit(1)
                            .contentTransition(.numericText())
                            .foregroundStyle(ActivityTint.distance(state))
                            .accessibilityLabel(Text(ActivityDistanceCaption.shortDistance(state)))
                    }
                } else {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .foregroundStyle(.gray)
                        .accessibilityLabel(Text("Out of reach"))
                }
            }
        }
        // Alone, the padlock matches the Locky logo facing it.
        .font(DeviceModel.hasUprightIsland ? .body.weight(.semibold) : .caption2.weight(.semibold))
    }
}

/// The padlock of the state of the Mac, closed or open, in white.
private struct ActivityPadlock: View {
    let state: LockyActivityAttributes.ContentState

    var body: some View {
        Image(systemName: state.lockState == .unlocked ? "lock.open.fill" : "lock.fill")
            .foregroundStyle(ActivityTint.lockState(state))
            .contentTransition(.symbolEffect(.replace))
            .accessibilityLabel(Text(state.lockState.localizedName))
    }
}

/// The Mac from the App Group: its product image with its wallpaper on screen, and the imitation of
/// its lock screen while locked.
struct ActivityMacImage: View {
    let family: MacFamily
    let state: LockyActivityAttributes.ContentState

    var body: some View {
        // Reduced images: iOS shows nothing of the activity when an image exceeds its place.
        MacDeviceImage(
            frame: ActivityImages.device.flatMap(UIImage.init(data:)).map {
                MacFrame(image: $0, screen: SharedStore.deviceScreen, hasWallpaper: true)
            },
            family: family,
            lockState: state.lockState,
            isConnected: state.isConnected,
            userPicture: ActivityImages.userPicture,
            isUnlocking: state.isUnlocking
        )
    }
}

/// "Unlocked · 25 min", "Unlocking…" or "Out of reach".
struct ActivityStateLine: View {
    let state: LockyActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 4) {
            if !state.isConnected {
                Text("Out of reach")
            } else if state.isUnlocking {
                Text("Unlocking…")
            } else {
                Text(state.lockState.localizedName)
                if let date = state.lockStateDate, date > .distantPast, state.lockState != .unknown {
                    Text("·")
                    SinceText(date: date)
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

/// "0.6 m away · locks beyond 1.5 m" (or why automatic locking does not apply).
struct ActivityDistanceCaption: View {
    let state: LockyActivityAttributes.ContentState

    var body: some View {
        // The narrow screens (outer screen of an iPhone Duo) get a shorter caption rather than a
        // cut one.
        let texts: [String] = self.texts
        ViewThatFits(in: .horizontal) {
            caption(texts[0])
            if texts.count > 2 {
                caption(texts[1])
            }
            // The last resort shrinks a little instead of being measured.
            Text(texts[texts.count - 1])
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    /// From the longest to the shortest.
    private var texts: [String] {
        let lock: String = Measurement(value: state.lockDistance, unit: UnitLength.meters).formatted(.lockyDistance)
        guard state.isConnected else { return [String(localized: "Your Mac is out of reach")] }
        guard state.isAutoLockEnabled else { return [String(localized: "Automatic locking paused")] }
        guard let distance = state.distance else { return [String(localized: "Locks beyond \(lock)")] }
        let formatted: String = Measurement(value: distance, unit: UnitLength.meters).formatted(.lockyDistance)
        return [
            String(localized: "\(formatted) away · locks beyond \(lock)"),
            String(localized: "\(formatted) · limit \(lock)"),
            formatted
        ]
    }

    /// The distance alone, for the compact Dynamic Island.
    static func shortDistance(_ state: LockyActivityAttributes.ContentState) -> String {
        guard state.isConnected, let distance = state.distance else { return "–" }
        return Measurement(value: distance, unit: UnitLength.meters).formatted(.lockyDistance)
    }
}

/// The track from the Mac to the padlock at the lock distance, the iPhone on it.
struct ActivityDistanceGauge: View {
    let state: LockyActivityAttributes.ContentState

    /// Blue at the Mac, red at the lock distance.
    static let gradient: Gradient = .init(colors: [LockyTint.unlock, LockyTint.lock])

    /// The color of the gauge at a fraction of the lock distance (red beyond it).
    static func color(at fraction: Double) -> Color {
        LockyTint.unlock.mix(with: LockyTint.lock, by: min(max(fraction, 0), 1), in: .device)
    }

    var body: some View {
        GeometryReader { proxy in
            let width: CGFloat = proxy.size.width
            let scale: Double = max(state.lockDistance * 1.4, (state.distance ?? 0) * 1.05, 0.5)
            let lockX: CGFloat = width * state.lockDistance / scale
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.2))
                    .frame(height: 5)
                Capsule()
                    .fill(LinearGradient(gradient: Self.gradient, startPoint: .leading, endPoint: .trailing))
                    .frame(width: lockX, height: 5)
                    .opacity(state.isAutoLockEnabled ? 0.9 : 0.3)
                Image(systemName: "lock.fill")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(LockyTint.lock, in: .circle)
                    .position(x: lockX, y: proxy.size.height / 2)
                    .opacity(state.isAutoLockEnabled ? 1 : 0.4)
                if state.isConnected, let distance = state.distance {
                    Image(systemName: "iphone")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(3)
                        .background(.white, in: .circle)
                        .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                        .position(x: min(max(width * min(distance, scale) / scale, 9), width - 9), y: proxy.size.height / 2)
                }
            }
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel(Text(ActivityDistanceCaption.shortDistance(state)))
    }
}

#Preview("Lock Screen", as: .content, using: LockyActivityAttributes(macName: "LeJack MacBook Pro Max", family: .macBook)) {
    LockyLiveActivity()
} contentStates: {
    LockyActivityAttributes.ContentState.preview
}

#Preview("Compact", as: .dynamicIsland(.compact), using: LockyActivityAttributes(macName: "MacBook Pro", family: .macBook)) {
    LockyLiveActivity()
} contentStates: {
    LockyActivityAttributes.ContentState.preview
}

#Preview("Expanded", as: .dynamicIsland(.expanded), using: LockyActivityAttributes(macName: "MacBook Pro", family: .macBook)) {
    LockyLiveActivity()
} contentStates: {
    LockyActivityAttributes.ContentState.preview
}

#Preview("Minimal", as: .dynamicIsland(.minimal), using: LockyActivityAttributes(macName: "MacBook Pro", family: .macBook)) {
    LockyLiveActivity()
} contentStates: {
    LockyActivityAttributes.ContentState.preview
}
