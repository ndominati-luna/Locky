import LockyKit
import SwiftUI

/// The Bluetooth devices around on a radar: the closer to the center, the stronger the signal; a
/// beam sweeps and lights them as it passes. Filled dots were heard by the Mac, rings by the
/// iPhone, both lying at the center.
struct BluetoothRadarView: View {
    let mac: [BluetoothNeighbor]
    let phone: [BluetoothNeighbor]
    /// The dot of the Mac and the iPhone at the center (hidden under a countdown).
    var showsCenter: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Blip {
        let angle: Double
        let distance: Double
        let size: CGFloat
        let color: Color
        let isFromPhone: Bool
    }

    /// One turn of the beam, in seconds.
    private static let sweepPeriod: Double = 4

    var body: some View {
        let blips: [Blip] = Self.blips(mac: mac, phone: phone)
        TimelineView(.animation(paused: reduceMotion)) { timeline in
            let sweep: Double = reduceMotion ? -.pi / 2 : (timeline.date.timeIntervalSinceReferenceDate / Self.sweepPeriod).truncatingRemainder(dividingBy: 1) * 2 * .pi
            Canvas { context, size in
                let center: CGPoint = .init(x: size.width / 2, y: size.height / 2)
                let radius: CGFloat = min(size.width, size.height) / 2 - 6
                drawRings(context, center: center, radius: radius)
                if !reduceMotion {
                    drawBeam(context, center: center, radius: radius, angle: sweep)
                }
                for blip in blips {
                    // Lit as the beam passes, then fading for most of a turn.
                    let behind: Double = (sweep - blip.angle).truncatingRemainder(dividingBy: 2 * .pi)
                    let sinceBeam: Double = behind < 0 ? behind + 2 * .pi : behind
                    let glow: Double = reduceMotion ? 1 : max(0, 1 - sinceBeam / (1.6 * .pi))
                    let point: CGPoint = .init(
                        x: center.x + cos(blip.angle) * radius * blip.distance,
                        y: center.y + sin(blip.angle) * radius * blip.distance
                    )
                    let rect: CGRect = .init(x: point.x - blip.size / 2, y: point.y - blip.size / 2, width: blip.size, height: blip.size)
                    var dot: GraphicsContext = context
                    dot.opacity = 0.35 + 0.65 * glow
                    if blip.isFromPhone {
                        dot.stroke(Path(ellipseIn: rect), with: .color(blip.color), lineWidth: 1.6)
                    } else {
                        dot.fill(Path(ellipseIn: rect), with: .color(blip.color))
                    }
                }
                if showsCenter {
                    drawCenter(context, center: center)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text("Radar of the Bluetooth devices around"))
    }

    private func drawRings(_ context: GraphicsContext, center: CGPoint, radius: CGFloat) {
        for fraction in [1.0 / 3, 2.0 / 3, 1.0] {
            let ringRadius: CGFloat = radius * fraction
            let rect: CGRect = .init(x: center.x - ringRadius, y: center.y - ringRadius, width: ringRadius * 2, height: ringRadius * 2)
            context.stroke(Path(ellipseIn: rect), with: .color(.secondary.opacity(0.25)), lineWidth: 1)
        }
        var cross: Path = .init()
        cross.move(to: .init(x: center.x - radius, y: center.y))
        cross.addLine(to: .init(x: center.x + radius, y: center.y))
        cross.move(to: .init(x: center.x, y: center.y - radius))
        cross.addLine(to: .init(x: center.x, y: center.y + radius))
        context.stroke(cross, with: .color(.secondary.opacity(0.12)), lineWidth: 1)
    }

    private func drawBeam(_ context: GraphicsContext, center: CGPoint, radius: CGFloat, angle: Double) {
        let width: Double = 0.9
        var wedge: Path = .init()
        wedge.move(to: center)
        wedge.addArc(center: center, radius: radius, startAngle: .radians(angle - width), endAngle: .radians(angle), clockwise: false)
        wedge.closeSubpath()
        let tint: Color = .init(red: 0.12, green: 0.55, blue: 1.0)
        context.fill(
            wedge,
            with: .conicGradient(
                Gradient(stops: [
                    .init(color: tint.opacity(0), location: 0),
                    .init(color: tint.opacity(0), location: 1 - width / (2 * .pi)),
                    .init(color: tint.opacity(0.35), location: 1)
                ]),
                center: center,
                angle: .radians(angle)
            )
        )
    }

    private func drawCenter(_ context: GraphicsContext, center: CGPoint) {
        let rect: CGRect = .init(x: center.x - 7, y: center.y - 7, width: 14, height: 14)
        context.fill(Path(ellipseIn: rect), with: .color(.init(red: 0.12, green: 0.55, blue: 1.0)))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: -4, dy: -4)), with: .color(.init(red: 0.12, green: 0.55, blue: 1.0).opacity(0.4)), lineWidth: 2)
    }

    private static func blips(mac: [BluetoothNeighbor], phone: [BluetoothNeighbor]) -> [Blip] {
        func blip(_ device: BluetoothNeighbor, isFromPhone: Bool) -> Blip {
            // -35 dBm against the devices, -100 dBm at the edge.
            let distance: Double = 0.1 + 0.88 * min(max(Double(-35 - device.rssi) / 65, 0), 1)
            return .init(
                angle: Double(stableHash(device.id + (isFromPhone ? "phone" : "mac")) % 3600) / 3600 * 2 * .pi,
                distance: distance,
                size: device.isNearby ? 9 : 6,
                color: color(device),
                isFromPhone: isFromPhone
            )
        }
        return mac.map { blip($0, isFromPhone: false) } + phone.map { blip($0, isFromPhone: true) }
    }

    static func color(_ device: BluetoothNeighbor) -> Color {
        switch device.company {
        case .apple: .init(red: 0.12, green: 0.55, blue: 1.0)
        case nil: .gray
        default: .teal
        }
    }

    /// FNV-1a: the same angle at every launch, unlike `Hasher`.
    private static func stableHash(_ string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return hash
    }
}

/// What the colors and shapes of the radar mean.
struct BluetoothRadarLegend: View {
    var body: some View {
        HStack(spacing: 14) {
            legend(Color(red: 0.12, green: 0.55, blue: 1.0), "Apple")
            legend(.teal, "Other brands")
            legend(.gray, "Unknown")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        HStack(spacing: 14) {
            HStack(spacing: 4) {
                Circle().fill(.secondary).frame(width: 7, height: 7)
                Text("Heard by your Mac")
            }
            HStack(spacing: 4) {
                Circle().stroke(.secondary, lineWidth: 1.5).frame(width: 7, height: 7)
                Text("Heard by your iPhone")
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func legend(_ color: Color, _ title: LocalizedStringKey) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(title)
        }
    }
}
