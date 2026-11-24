import SwiftUI

/// The Apple Pro Display XDR on its Pro Stand, around any picture: the screen of a Mac without a
/// display (Mac mini, Mac Studio, Mac Pro), which stands on the desk next to its foot, or the film
/// of the easter egg.
///
/// It is handled like the real one, without any button (see ``ProDisplayXDRGestureHandlers``): two
/// fingers twist it, it follows them and settles, once released, in landscape or portrait, the
/// closer; they also slide it up and down its stand. One finger tilts and swivels the panel on its
/// stand, which does not move. A double tap puts it all back as it came: landscape, upright, at
/// its first height. Turned toward portrait, it rises to clear the desk, as the real stand
/// requires. Settled in another orientation, its picture goes black for an instant and comes back
/// upright, as macOS does with a rotated display. The panel and the arm are drawn, sharp at any
/// size; the aluminium foot comes from the artwork of macOS (`Tools/MacCatalog/make_xdr.py`).
/// Measures in widths of the panel.
struct ProDisplayXDR<Screen: View, Accessory: View>: View {
    @Binding var pose: ProDisplayXDRPose
    /// Width of the accessory on the desk, in widths of the panel.
    let accessoryWidth: CGFloat
    let screen: Screen
    let accessory: Accessory

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Disabled, it cannot be handled: the gestures let the touches go by.
    @Environment(\.isEnabled) private var isEnabled
    /// The rotation the picture is laid out upright for: 0 landscape, -90 or 90 portrait.
    @State private var pictureRotation: Double
    @State private var isBlank: Bool = false
    @State private var upright: Task<Void, Never>?
    @State private var unit: CGFloat = 1
    /// The hands at work, on top of ``pose``, since their gesture began.
    @State private var turning: Double = 0
    @State private var lifting: Double = 0
    @State private var leaning: CGSize = .zero
    @State private var isTurning: Bool = false
    @State private var isLifting: Bool = false
    /// Two fingers came down during a one-finger gesture: it waits for its end.
    @State private var isLeanSuspended: Bool = false

    init(
        pose: Binding<ProDisplayXDRPose>,
        accessoryWidth: CGFloat,
        @ViewBuilder screen: () -> Screen,
        @ViewBuilder accessory: () -> Accessory
    ) {
        _pose = pose
        self.accessoryWidth = accessoryWidth
        self.screen = screen()
        self.accessory = accessory()
        _pictureRotation = State(initialValue: pose.wrappedValue.rotation)
    }

    var body: some View {
        GeometryReader { proxy in
            let unit: CGFloat = proxy.size.width
            let height: CGFloat = proxy.size.height
            let footTop: CGFloat = height - XDRMeasures.footHeight * unit
            let desk: CGFloat = footTop + XDRMeasures.sole * unit
            let rotation: Double = shownRotation
            let center: CGFloat = footTop - XDRMeasures.pivotHeight(rotation: rotation, travel: shownTravel) * unit
            let bottom: CGFloat = center + XDRMeasures.halfHeight(rotation: rotation) * unit
            ZStack {
                // The stand does not move: only the panel turns, tilts and swivels on it.
                XDRArm(showing: max(0, footTop - bottom))
                    .frame(width: XDRMeasures.armWidth * unit, height: max(0, footTop - center))
                    .position(x: unit / 2, y: (center + footTop) / 2)
                Image(.xdrFoot)
                    .resizable()
                    .frame(width: XDRMeasures.footWidth * unit, height: XDRMeasures.footHeight * unit)
                    .position(x: unit / 2, y: footTop + XDRMeasures.footHeight * unit / 2)
                XDRPanel(unit: unit, isPortrait: abs(pictureRotation) > 45, isBlank: isBlank) {
                    screen
                }
                .rotationEffect(.degrees(rotation - pictureRotation))
                // The hinges stay level and upright, whatever the orientation of the panel.
                .rotation3DEffect(.degrees(shownTilt), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
                .rotation3DEffect(.degrees(shownSwivel), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .position(x: unit / 2, y: center)
                // In front of the foot and of the panel, on the desk, at the right of the stand.
                accessory
                    .frame(width: accessoryWidth * unit, height: desk, alignment: .bottom)
                    .position(x: (XDRMeasures.accessoryLeft + accessoryWidth / 2) * unit, y: desk / 2)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { unit = max($0, 1) }
        .aspectRatio(1 / XDRMeasures.canvasHeight(isPortrait: pose.isPortrait), contentMode: .fit)
        .contentShape(.rect)
        .proDisplayXDRGestures(handlers)
        .accessibilityActions {
            // Disabled (the Mac out of reach), the display stays as it is.
            if isEnabled {
                Button("Rotate the display") {
                    withAnimation(settling) { pose.rotation = pose.isPortrait ? 0 : -90 }
                }
                Button("Put the display back") {
                    withAnimation(settling) { pose = .init() }
                }
            }
        }
        // Settled by the hands or turned from outside (an accessibility action of the caller).
        .onChange(of: pose.rotation) {
            showUpright()
        }
    }

    // MARK: What is shown: the pose, plus the hands, a little elastic past the limits of the stand

    private var shownRotation: Double {
        Self.elastic(pose.rotation + turning, in: -90...90, slack: 20)
    }

    private var shownTravel: Double {
        Self.elastic(pose.height + lifting, in: 0...1, slack: 0.12)
    }

    private var shownTilt: Double {
        Self.elastic(pose.tilt + leaning.height, in: ProDisplayXDRPose.tiltRange, slack: 6)
    }

    private var shownSwivel: Double {
        Self.elastic(pose.swivel + leaning.width, in: ProDisplayXDRPose.swivelRange, slack: 8)
    }

    private var settling: Animation? {
        reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.18)
    }

    // MARK: The hands

    private var handlers: ProDisplayXDRGestureHandlers {
        .init(
            turnChanged: { angle in
                twoFingersDown()
                isTurning = true
                turning = angle.degrees
            },
            turnEnded: { _ in
                // The closer of landscape and portrait, from where the panel was let go.
                let settled: Double = [-90, 0, 90].min { abs($0 - shownRotation) < abs($1 - shownRotation) } ?? 0
                isTurning = false
                withAnimation(settling) {
                    pose.rotation = settled
                    turning = 0
                }
            },
            liftChanged: { points in
                twoFingersDown()
                isLifting = true
                lifting = Double(points / (unit * XDRMeasures.travel))
            },
            liftEnded: { _ in
                withAnimation(settling) {
                    pose.height = min(max(pose.height + lifting, 0), 1)
                    lifting = 0
                }
                isLifting = false
            },
            leanChanged: { translation in
                guard !isLeanSuspended, !isTurning, !isLifting else { return }
                // A quarter of a degree per point: right turns it right, up leans it back.
                leaning = .init(width: translation.width * 0.25, height: -translation.height * 0.25)
            },
            leanEnded: { _ in
                guard !isLeanSuspended else {
                    isLeanSuspended = false
                    return
                }
                withAnimation(settling) { commitLean() }
            },
            reset: {
                isLeanSuspended = false
                withAnimation(settling) {
                    pose = .init()
                    turning = 0
                    lifting = 0
                    leaning = .zero
                }
            }
        )
    }

    /// Two fingers on the display: a lean in progress stays where it is and waits for its end.
    private func twoFingersDown() {
        guard !isTurning, !isLifting, leaning != .zero else { return }
        commitLean()
        isLeanSuspended = true
    }

    /// Keeps the lean where it was let go, within the stand.
    private func commitLean() {
        pose.tilt = min(max(pose.tilt + leaning.height, ProDisplayXDRPose.tiltRange.lowerBound), ProDisplayXDRPose.tiltRange.upperBound)
        pose.swivel = min(max(pose.swivel + leaning.width, ProDisplayXDRPose.swivelRange.lowerBound), ProDisplayXDRPose.swivelRange.upperBound)
        leaning = .zero
    }

    /// Once the panel has settled in another orientation: black, the picture upright, the picture
    /// again.
    private func showUpright() {
        upright?.cancel()
        guard !reduceMotion else {
            pictureRotation = pose.rotation
            return
        }
        upright = Task {
            try? await Task.sleep(for: .milliseconds(550))
            guard !Task.isCancelled, abs(pictureRotation - pose.rotation) > 1, !isTurning else { return }
            withAnimation(.easeIn(duration: 0.12)) { isBlank = true }
            try? await Task.sleep(for: .milliseconds(160))
            var transaction: Transaction = .init()
            transaction.disablesAnimations = true
            withTransaction(transaction) { pictureRotation = pose.rotation }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(.easeOut(duration: 0.3)) { isBlank = false }
        }
    }

    /// The value within its range, and past it, a resistance that grows to `slack` at most.
    private static func elastic(_ value: Double, in range: ClosedRange<Double>, slack: Double) -> Double {
        if value > range.upperBound {
            let excess: Double = value - range.upperBound
            return range.upperBound + slack * (1 - 1 / (excess / slack + 1))
        }
        if value < range.lowerBound {
            let excess: Double = range.lowerBound - value
            return range.lowerBound - slack * (1 - 1 / (excess / slack + 1))
        }
        return value
    }
}

extension ProDisplayXDR where Accessory == EmptyView {
    /// The display alone, nothing on the desk.
    init(pose: Binding<ProDisplayXDRPose>, @ViewBuilder screen: () -> Screen) {
        self.init(pose: pose, accessoryWidth: 0, screen: screen) {
            EmptyView()
        }
    }
}

/// The measures of the display, in widths of the panel, from the artwork of macOS (1024 px: panel
/// 1000 x 572 px with a 12 px border, arm 248 px wide and 89 px showing at its lowest, foot 74 px
/// high with its shadow, its sole 46 px under its top), and the 120 mm of travel of the Pro Stand
/// (the panel is 718 mm wide).
private enum XDRMeasures {
    static let panelHeight: CGFloat = 0.572
    static let border: CGFloat = 0.012
    static let corner: CGFloat = 0.006
    static let armWidth: CGFloat = 0.248
    static let footWidth: CGFloat = 0.982
    static let footHeight: CGFloat = 0.074
    static let sole: CGFloat = 0.046
    /// Where the accessory starts on the desk, just over the edge of the foot.
    static let accessoryLeft: CGFloat = 0.7
    /// How far the panel slides along the stand.
    static let travel: CGFloat = 0.167
    /// The least arm showing under the panel, whatever its orientation.
    static let clearance: CGFloat = 0.045
    /// Middle of the panel above the foot, at its lowest, held landscape.
    static let lowestPivot: CGFloat = 0.089 + 0.572 / 2

    /// Half the height the panel takes, turned by `rotation` degrees.
    static func halfHeight(rotation: Double) -> CGFloat {
        let radians: Double = rotation * .pi / 180
        return (panelHeight * abs(cos(radians)) + abs(sin(radians))) / 2
    }

    /// Middle of the panel above the foot: its place on the stand, raised as far as needed for its
    /// corners to clear the desk while it turns.
    static func pivotHeight(rotation: Double, travel: Double) -> CGFloat {
        max(lowestPivot, halfHeight(rotation: rotation) + clearance) + self.travel * travel
    }

    /// Room for the panel at the top of the stand, in the orientation it rests in.
    static func canvasHeight(isPortrait: Bool) -> CGFloat {
        let rotation: Double = isPortrait ? 90 : 0
        return pivotHeight(rotation: rotation, travel: 1) + halfHeight(rotation: rotation) + footHeight
    }
}

/// The black glass of the panel, its aluminium edge and the picture inside its border.
private struct XDRPanel<Screen: View>: View {
    let unit: CGFloat
    let isPortrait: Bool
    let isBlank: Bool
    @ViewBuilder var screen: Screen

    var body: some View {
        let long: CGFloat = unit
        let short: CGFloat = XDRMeasures.panelHeight * unit
        RoundedRectangle(cornerRadius: XDRMeasures.corner * unit)
            .fill(Color(white: 0.02))
            .overlay {
                screen
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay {
                        Color.black
                            .opacity(isBlank ? 1 : 0)
                    }
                    .clipShape(.rect(cornerRadius: XDRMeasures.corner * unit / 3))
                    .padding(XDRMeasures.border * unit)
            }
            .overlay {
                RoundedRectangle(cornerRadius: XDRMeasures.corner * unit)
                    .strokeBorder(Color(white: 0.32), lineWidth: max(0.5, 0.0015 * unit))
            }
            .frame(width: isPortrait ? short : long, height: isPortrait ? long : short)
            .shadow(color: .black.opacity(0.35), radius: 0.012 * unit, y: 0.006 * unit)
    }
}

/// The arm of the stand: hidden behind the panel up to its middle, then brushed aluminium down to
/// the foot, darker under the panel, as in the artwork.
private struct XDRArm: View {
    let showing: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            Color(white: 0.45)
            LinearGradient(
                stops: [
                    .init(color: Color(white: 0.47), location: 0),
                    .init(color: Color(white: 0.61), location: 0.3),
                    .init(color: Color(white: 0.68), location: 0.65),
                    .init(color: Color(white: 0.72), location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: showing)
        }
        .overlay {
            LinearGradient(
                stops: [
                    .init(color: .black.opacity(0.14), location: 0),
                    .init(color: .clear, location: 0.04),
                    .init(color: .clear, location: 0.96),
                    .init(color: .black.opacity(0.14), location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        }
    }
}
