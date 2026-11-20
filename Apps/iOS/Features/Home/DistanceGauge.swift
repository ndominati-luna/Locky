import LockyKit
import SwiftUI

/// Horizontal scale from the Mac (left) to infinity (right), like the original Locky scale.
/// Logarithmic so short distances get room.
///
/// Above the scale, this very iPhone (its exact product image, rendered by the Mac) points at the
/// current estimated distance. On the scale, the padlock is the lock distance: drag it or touch
/// anywhere to move it (or adjust it with VoiceOver).
struct DistanceGauge: View {
    let currentDistance: Double?
    @Binding var lockDistance: Double
    let isMoving: Bool
    let family: MacFamily
    let phoneImage: Data?
    let onCommit: () -> Void

    @State private var trackWidth: CGFloat = 1
    private let range: ClosedRange<Double> = DistanceModel.lockDistanceRange
    private let handleSize: CGFloat = 36
    private let markerSize: CGSize = .init(width: 30, height: 52)

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            Image(systemName: family.systemImage)
                .foregroundStyle(.secondary)
                .frame(height: handleSize)
                .accessibilityHidden(true)
            VStack(spacing: 2) {
                ZStack(alignment: .leading) {
                    Color.clear
                    if let currentDistance {
                        PhoneMarker(imageData: phoneImage, isMoving: isMoving)
                            .frame(width: markerSize.width, height: markerSize.height)
                            .offset(x: position(of: currentDistance) - markerSize.width / 2)
                            .animation(.smooth(duration: 0.6), value: currentDistance)
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
                    PadlockHandle(isBeyond: (currentDistance ?? 0) > lockDistance)
                        .frame(width: handleSize, height: handleSize)
                        .offset(x: position(of: lockDistance) - handleSize / 2)
                }
                .frame(height: handleSize)
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trackWidth = max($0, 1) }
            // Markers are centered on their value: keep half a padlock free on both ends.
            .padding(.horizontal, handleSize / 2)
            // The whole scale reacts (drag the padlock or touch anywhere to move it there), in a
            // coordinate space that does not move with the padlock. High priority so the
            // surrounding list does not swallow the touch.
            .contentShape(.rect)
            .highPriorityGesture(dragGesture)
            Image(systemName: "infinity")
                .foregroundStyle(.secondary)
                .frame(height: handleSize)
                .accessibilityHidden(true)
        }
        .accessibilityElement()
        .accessibilityLabel(Text("Lock distance"))
        .accessibilityValue(Text(Measurement(value: lockDistance, unit: UnitLength.meters), format: .lockyDistance))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: lockDistance = min(range.upperBound, lockDistance + 0.5)
            case .decrement: lockDistance = max(range.lowerBound, lockDistance - 0.5)
            @unknown default: break
            }
            onCommit()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                // The gesture lives on the padded scale: remove the padding to get the track position.
                lockDistance = distance(at: value.location.x - handleSize / 2)
            }
            .onEnded { _ in
                lockDistance = (lockDistance * 10).rounded() / 10
                onCommit()
            }
    }

    /// The scale shared with the track of the Mac: both show the iPhone and the padlock at the same
    /// place.
    private func position(of distance: Double) -> CGFloat {
        CGFloat(DistanceScale.ratio(for: distance)) * trackWidth
    }

    private func distance(at position: CGFloat) -> Double {
        DistanceScale.distance(at: Double(position / trackWidth))
    }
}

/// The draggable padlock: blue (unlocked) on this side, red once the iPhone is beyond, like on
/// the Mac.
private struct PadlockHandle: View {
    let isBeyond: Bool

    var body: some View {
        Image(systemName: isBeyond ? "lock.fill" : "lock.open.fill")
            .font(.callout.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(isBeyond ? LockyTint.lock : LockyTint.unlock, in: .circle)
            .shadow(radius: 3, y: 1)
            .contentTransition(.symbolEffect(.replace))
    }
}

/// This iPhone pointing at its distance on the scale, like the original Locky slider.
private struct PhoneMarker: View {
    let imageData: Data?
    let isMoving: Bool

    var body: some View {
        VStack(spacing: 1) {
            Group {
                if let image = imageData.flatMap(UIImage.init(data:)) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    Image(systemName: LocalDevice.symbolName)
                        .resizable()
                        .scaledToFit()
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            .symbolEffect(.bounce, options: .repeating, isActive: isMoving)
            Image(systemName: "arrowtriangle.down.fill")
                .font(.caption2)
                .foregroundStyle(.tint)
        }
        .accessibilityHidden(true)
    }
}
