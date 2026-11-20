import LockyKit
import SwiftUI

/// The iPhone moving away from the Mac towards the lock distance (the padlock), live.
///
/// The twin of the distance gauge of the iPhone: same scale (``DistanceScale``), same ends (the Mac,
/// infinity), same colors, so both screens show the iPhone and the padlock at the same place.
struct WalkAwayTrack: View {
    let distance: Double?
    let lockDistance: Double
    let phoneImage: NSImage?
    let family: MacFamily

    @State private var trackWidth: CGFloat = 1
    private let padlockSize: CGFloat = 36
    private let markerSize: CGSize = .init(width: 30, height: 52)

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Image(systemName: family.systemImage)
                .foregroundStyle(Color.secondary)
                .frame(height: padlockSize)
            VStack(spacing: 2) {
                ZStack(alignment: .leading) {
                    Color.clear
                    if let distance {
                        PhoneMarker(image: phoneImage)
                            .frame(width: markerSize.width, height: markerSize.height)
                            .offset(x: position(of: distance) - markerSize.width / 2)
                            .transition(.opacity)
                    }
                }
                .frame(height: markerSize.height)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.quaternary)
                        .frame(height: 8)
                    Capsule()
                        .fill(LinearGradient(colors: [.green, .yellow], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(8, position(of: lockDistance)), height: 8)
                    Capsule()
                        .fill(.red.opacity(0.4))
                        .frame(width: max(0, trackWidth - position(of: lockDistance)), height: 8)
                        .offset(x: position(of: lockDistance))
                    Image(systemName: isBeyond ? "lock.fill" : "lock.open.fill")
                        .font(.callout.bold())
                        .foregroundStyle(.white)
                        .frame(width: padlockSize, height: padlockSize)
                        .background(isBeyond ? Self.lockRed : Self.unlockBlue, in: .circle)
                        .shadow(radius: 3, y: 1)
                        .contentTransition(.symbolEffect(.replace))
                        .offset(x: position(of: lockDistance) - padlockSize / 2)
                }
                .frame(height: padlockSize)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = max($0, 1) }
            // Markers are centered on their value: keep half a padlock free on both ends.
            .padding(.horizontal, padlockSize / 2)
            Image(systemName: "infinity")
                .foregroundStyle(Color.secondary)
                .frame(height: padlockSize)
        }
        .animation(.smooth(duration: 0.6), value: distance)
        .animation(.smooth, value: isBeyond)
        .accessibilityElement()
        .accessibilityLabel(Text("Distance of the iPhone"))
        .accessibilityValue(distance.map { Text(Measurement(value: $0, unit: UnitLength.meters), format: .lockyDistance) } ?? Text("Unknown"))
    }

    /// The flat red and blue of the round Locky button, as on the iPhone.
    private static let lockRed: Color = .init(red: 1.0, green: 0.36, blue: 0.32)
    private static let unlockBlue: Color = .init(red: 0.11, green: 0.57, blue: 0.96)

    private var isBeyond: Bool {
        (distance ?? 0) > lockDistance
    }

    private func position(of value: Double) -> CGFloat {
        CGFloat(DistanceScale.ratio(for: value)) * trackWidth
    }
}

/// The paired iPhone pointing at its distance.
private struct PhoneMarker: View {
    let image: NSImage?

    var body: some View {
        VStack(spacing: 1) {
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: "iphone")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.primary)
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 3, y: 1)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(Color.brandArt)
        }
        .accessibilityHidden(true)
    }
}
