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
///
/// Only fingers set down on the panel move it (its height, its tilt, its orientation). A Mac on the
/// desk is linked to the panel by its cable, which hangs from the back of the panel beside the
/// arm; two fingers set down on the Mac slide it along the desk, the display staying put, and the
/// cable follows. In front, the desk can hold more (a keyboard, a trackpad), laid down by the
/// camera of the artwork; two fingers spreading or closing on it, or one finger moving on it, are
/// its own. One finger anywhere else pulls the whole desk (the rubber band of the caller).
struct ProDisplayXDR<Screen: View, Accessory: View, Front: View>: View {
    @Binding var pose: ProDisplayXDRPose
    /// Width of the accessory on the desk, in widths of the panel.
    let accessoryWidth: CGFloat
    /// Its width over its height, where the fingers find it.
    let accessoryAspectRatio: CGFloat
    /// How far it was slid along the desk, in widths of the panel.
    @Binding var accessoryOffset: Double
    /// The accessory is a Mac: its cable runs to the back of the panel.
    let hasCable: Bool
    /// How far in front of the display what lies on the desk reaches, in centimetres.
    let frontDepth: CGFloat
    /// Where what lies in front takes two fingers for itself, and what they do there: how many
    /// times wider apart side to side, then the end.
    let frontArea: (DeskCamera) -> CGRect
    let frontPinchChanged: (CGFloat) -> Void
    let frontPinchEnded: (CGFloat) -> Void
    /// Where what lies in front takes one finger for itself, and how far it moved, `nil` once lifted.
    let frontPointerArea: (DeskCamera) -> CGRect
    let frontPointerMoved: (CGSize?) -> Void
    /// One finger off the panel and off what lies in front: how far it pulled, `nil` once lifted.
    let pulled: ((CGSize?) -> Void)?
    let screen: Screen
    let accessory: Accessory
    let front: (DeskCamera) -> Front

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
    /// What the fingers came down on, which decides what they do. Without a place (a trackpad or a
    /// mouse on the Mac), the panel.
    @State private var twoFingers: XDRTarget = .panel
    @State private var oneFinger: XDRTarget = .panel
    @State private var isPanning: Bool = false
    @State private var isPinching: Bool = false
    @State private var sliding: Double = 0
    /// One finger pulling the whole desk; more fingers came down during the pull: it waits for its
    /// end.
    @State private var isPulling: Bool = false
    @State private var isPullSuspended: Bool = false

    init(
        pose: Binding<ProDisplayXDRPose>,
        accessoryWidth: CGFloat,
        accessoryAspectRatio: CGFloat = 1,
        accessoryOffset: Binding<Double> = .constant(0),
        hasCable: Bool = false,
        frontDepth: CGFloat = 0,
        frontArea: @escaping (DeskCamera) -> CGRect = { _ in .null },
        frontPinchChanged: @escaping (CGFloat) -> Void = { _ in },
        frontPinchEnded: @escaping (CGFloat) -> Void = { _ in },
        frontPointerArea: @escaping (DeskCamera) -> CGRect = { _ in .null },
        frontPointerMoved: @escaping (CGSize?) -> Void = { _ in },
        pulled: ((CGSize?) -> Void)? = nil,
        @ViewBuilder screen: () -> Screen,
        @ViewBuilder accessory: () -> Accessory,
        @ViewBuilder front: @escaping (DeskCamera) -> Front
    ) {
        _pose = pose
        self.accessoryWidth = accessoryWidth
        self.accessoryAspectRatio = accessoryAspectRatio
        _accessoryOffset = accessoryOffset
        self.hasCable = hasCable
        self.frontDepth = frontDepth
        self.frontArea = frontArea
        self.frontPinchChanged = frontPinchChanged
        self.frontPinchEnded = frontPinchEnded
        self.frontPointerArea = frontPointerArea
        self.frontPointerMoved = frontPointerMoved
        self.pulled = pulled
        self.screen = screen()
        self.accessory = accessory()
        self.front = front
        _pictureRotation = State(initialValue: pose.wrappedValue.rotation)
    }

    var body: some View {
        GeometryReader { proxy in
            let unit: CGFloat = proxy.size.width
            // Above what lies on the desk in front.
            let height: CGFloat = proxy.size.height - XDRMeasures.frontBand(depth: frontDepth) * unit
            let footTop: CGFloat = height - XDRMeasures.footHeight * unit
            let desk: CGFloat = footTop + XDRMeasures.sole * unit
            let rotation: Double = shownRotation
            let center: CGFloat = footTop - XDRMeasures.pivotHeight(rotation: rotation, travel: shownTravel) * unit
            let bottom: CGFloat = center + XDRMeasures.halfHeight(rotation: rotation) * unit
            let mac: CGRect = accessoryFrame(unit: unit, desk: desk)
            ZStack {
                Image(.xdrFoot)
                    .resizable()
                    .frame(width: XDRMeasures.footWidth * unit, height: XDRMeasures.footHeight * unit)
                    .position(x: unit / 2, y: footTop + XDRMeasures.footHeight * unit / 2)
                if hasCable {
                    // It hangs from the back of the panel beside the arm, on the side of the Mac,
                    // over the edge of the plate of the foot, down onto the desk in front of it,
                    // then behind the Mac. As the Mac changes sides, it slips behind the arm to the
                    // other one.
                    XDRCable(
                        side: mac.midX >= unit / 2 ? 1 : -1,
                        center: unit / 2,
                        hang: XDRMeasures.cableOffset * unit,
                        top: bottom - XDRMeasures.border * 3 * unit,
                        plate: footTop + XDRMeasures.plateTop * unit,
                        desk: desk,
                        end: mac.midX >= unit / 2 ? mac.minX + mac.width * 0.3 : mac.maxX - mac.width * 0.3,
                        mac: mac.minX...mac.maxX,
                        width: XDRMeasures.cableWidth * unit
                    )
                    .animation(settling, value: mac.midX >= unit / 2)
                }
                // The stand does not move: only the panel turns, tilts and swivels on it.
                XDRArm(showing: max(0, footTop - bottom))
                    .frame(width: XDRMeasures.armWidth * unit, height: max(0, footTop - center))
                    .position(x: unit / 2, y: (center + footTop) / 2)
                XDRPanel(unit: unit, isPortrait: abs(pictureRotation) > 45, isBlank: isBlank) {
                    screen
                }
                .rotationEffect(.degrees(rotation - pictureRotation))
                // The hinges stay level and upright, whatever the orientation of the panel.
                .rotation3DEffect(.degrees(shownTilt), axis: (x: 1, y: 0, z: 0), perspective: 0.35)
                .rotation3DEffect(.degrees(shownSwivel), axis: (x: 0, y: 1, z: 0), perspective: 0.35)
                .position(x: unit / 2, y: center)
                // In front of the foot and of the panel, on the desk, at the right of the stand
                // unless slid elsewhere.
                accessory
                    .frame(width: accessoryWidth * unit, height: desk, alignment: .bottom)
                    .position(x: mac.midX, y: desk / 2)
                front(XDRMeasures.camera(unit: unit, desk: desk))
                    .frame(width: unit, height: proxy.size.height, alignment: .topLeading)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { unit = max($0, 1) }
        .aspectRatio(1 / (XDRMeasures.canvasHeight(isPortrait: pose.isPortrait) + XDRMeasures.frontBand(depth: frontDepth)), contentMode: .fit)
        .contentShape(.rect)
        .proDisplayXDRGestures(handlers)
        .accessibilityActions {
            // Disabled (the Mac out of reach), the display stays as it is.
            if isEnabled {
                Button("Rotate the display") {
                    withAnimation(settling) { pose.rotation = pose.isPortrait ? 0 : -90 }
                }
                Button("Put the display back") {
                    withAnimation(settling) {
                        pose = .init()
                        accessoryOffset = 0
                    }
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

    /// Along the desk, from the edge of the panel to the other.
    private var accessoryRange: ClosedRange<Double> {
        let left: Double = -Double(XDRMeasures.accessoryLeft)
        return left...max(left, Double(1 - XDRMeasures.accessoryLeft - accessoryWidth))
    }

    private var shownAccessoryOffset: Double {
        min(max(accessoryOffset + sliding, accessoryRange.lowerBound), accessoryRange.upperBound)
    }

    /// Where the accessory stands, on the desk under its middle.
    private func accessoryFrame(unit: CGFloat, desk: CGFloat) -> CGRect {
        let width: CGFloat = accessoryWidth * unit
        let height: CGFloat = min(width / max(accessoryAspectRatio, 0.01), desk)
        let left: CGFloat = (XDRMeasures.accessoryLeft + CGFloat(shownAccessoryOffset)) * unit
        return .init(x: left, y: desk - height, width: width, height: height)
    }

    private var settling: Animation? {
        reduceMotion ? nil : .spring(duration: 0.55, bounce: 0.18)
    }

    /// The desk under the foot, out of the layout, for the fingers.
    private var desk: CGFloat {
        unit * (XDRMeasures.canvasHeight(isPortrait: pose.isPortrait) - XDRMeasures.footHeight + XDRMeasures.sole)
    }

    /// Where the panel shows, turned as it is, for the fingers that come down on it.
    private var panelFrame: CGRect {
        let footTop: CGFloat = unit * (XDRMeasures.canvasHeight(isPortrait: pose.isPortrait) - XDRMeasures.footHeight)
        let rotation: Double = shownRotation
        let center: CGFloat = footTop - XDRMeasures.pivotHeight(rotation: rotation, travel: shownTravel) * unit
        let radians: Double = rotation * .pi / 180
        let halfWidth: CGFloat = (CGFloat(abs(cos(radians))) + XDRMeasures.panelHeight * CGFloat(abs(sin(radians)))) / 2 * unit
        let halfHeight: CGFloat = XDRMeasures.halfHeight(rotation: rotation) * unit
        return .init(x: unit / 2 - halfWidth, y: center - halfHeight, width: halfWidth * 2, height: halfHeight * 2)
            .insetBy(dx: -0.02 * unit, dy: -0.02 * unit)
    }

    // MARK: The hands

    private var handlers: ProDisplayXDRGestureHandlers {
        .init(
            twoFingersBegan: { point in
                // More fingers during a pull: the desk goes back, the pull waits for its end.
                if isPulling {
                    isPulling = false
                    isPullSuspended = true
                    pulled?(nil)
                }
                // Where two fingers come down decides: the accessory, what lies in front, the
                // panel, or nothing.
                guard !isPanning, !isTurning, !isPinching else { return }
                let margin: CGFloat = 0.04 * unit
                if accessoryWidth > 0, accessoryFrame(unit: unit, desk: desk).insetBy(dx: -margin, dy: -margin).contains(point) {
                    twoFingers = .accessory
                } else if frontArea(XDRMeasures.camera(unit: unit, desk: desk)).insetBy(dx: -margin, dy: -margin).contains(point) {
                    twoFingers = .front
                } else if panelFrame.contains(point) {
                    twoFingers = .panel
                } else {
                    twoFingers = .elsewhere
                }
            },
            turnChanged: { angle in
                guard twoFingers == .panel else { return }
                twoFingersDown()
                isTurning = true
                turning = angle.degrees
            },
            turnEnded: { _ in
                guard isTurning else {
                    twoFingersUp()
                    return
                }
                // The closer of landscape and portrait, from where the panel was let go.
                let settled: Double = [-90, 0, 90].min { abs($0 - shownRotation) < abs($1 - shownRotation) } ?? 0
                isTurning = false
                withAnimation(settling) {
                    pose.rotation = settled
                    turning = 0
                }
            },
            panChanged: { translation in
                isPanning = true
                switch twoFingers {
                case .accessory:
                    twoFingersDown()
                    sliding = Double(translation.width / unit)
                case .panel:
                    lift(-translation.height)
                case .front, .elsewhere:
                    break
                }
            },
            panEnded: { _ in
                isPanning = false
                switch twoFingers {
                case .accessory:
                    // Left where the fingers let it go, on the desk.
                    accessoryOffset = shownAccessoryOffset
                    sliding = 0
                case .panel:
                    endLift()
                case .front, .elsewhere:
                    break
                }
                twoFingersUp()
            },
            pinchChanged: { ratio in
                isPinching = true
                if twoFingers == .front {
                    frontPinchChanged(ratio)
                }
            },
            pinchEnded: { ratio in
                isPinching = false
                if twoFingers == .front {
                    frontPinchEnded(ratio)
                }
                twoFingersUp()
            },
            liftChanged: { points in
                lift(points)
            },
            liftEnded: { _ in
                endLift()
            },
            oneFingerBegan: { point in
                // Where one finger comes down decides: what lies in front, the panel, or the
                // whole desk.
                let margin: CGFloat = 0.02 * unit
                if frontPointerArea(XDRMeasures.camera(unit: unit, desk: desk)).insetBy(dx: -margin, dy: -margin).contains(point) {
                    oneFinger = .front
                } else if panelFrame.contains(point) {
                    oneFinger = .panel
                } else {
                    oneFinger = .elsewhere
                }
            },
            leanChanged: { translation in
                switch oneFinger {
                case .front:
                    frontPointerMoved(translation)
                case .elsewhere, .accessory:
                    guard !isPullSuspended, !isTurning, !isLifting, !isPanning, !isPinching else { return }
                    isPulling = true
                    pulled?(translation)
                case .panel:
                    guard !isLeanSuspended, !isTurning, !isLifting else { return }
                    // A quarter of a degree per point: right turns it right, up leans it back.
                    leaning = .init(width: translation.width * 0.25, height: -translation.height * 0.25)
                }
            },
            leanEnded: { _ in
                defer { oneFinger = .panel }
                switch oneFinger {
                case .front:
                    frontPointerMoved(nil)
                    return
                case .elsewhere, .accessory:
                    isPullSuspended = false
                    if isPulling {
                        isPulling = false
                        pulled?(nil)
                    }
                    return
                case .panel:
                    break
                }
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
                    accessoryOffset = 0
                    sliding = 0
                }
            }
        )
    }

    /// Every two-finger gesture is over: the next ones decide again where they are.
    private func twoFingersUp() {
        guard !isPanning, !isTurning, !isPinching else { return }
        twoFingers = .panel
    }

    /// The panel along its stand, `points` up since the fingers began.
    private func lift(_ points: CGFloat) {
        twoFingersDown()
        isLifting = true
        lifting = Double(points / (unit * XDRMeasures.travel))
    }

    private func endLift() {
        guard isLifting else { return }
        withAnimation(settling) {
            pose.height = min(max(pose.height + lifting, 0), 1)
            lifting = 0
        }
        isLifting = false
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

/// What the fingers came down on.
private enum XDRTarget {
    case panel
    /// The Mac on the desk.
    case accessory
    /// What lies in front: the keyboard, the trackpad.
    case front
    case elsewhere
}

extension ProDisplayXDR where Accessory == EmptyView, Front == EmptyView {
    /// The display alone, nothing on the desk.
    init(pose: Binding<ProDisplayXDRPose>, @ViewBuilder screen: () -> Screen) {
        self.init(pose: pose, accessoryWidth: 0, screen: screen) {
            EmptyView()
        } front: { _ in
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
    /// The cable of the accessory hangs from the back of the panel just beside the arm (124 px from
    /// its middle), over the plate of the foot (142 px), whose front edge is 28 px under the top of
    /// the artwork of the foot; it is about 5 mm thick.
    static let cableOffset: CGFloat = 0.133
    static let plateTop: CGFloat = 0.028
    static let cableWidth: CGFloat = 0.007
    /// The panel is 71.8 cm wide. The artwork sees it from a little above, as the Macs of macOS;
    /// what lies on the desk in front, from about 13° above.
    static let panelWidth: CGFloat = 71.8
    private static let cameraDistance: CGFloat = 220
    private static let cameraHeight: CGFloat = 53

    /// The camera of the artwork, for a panel `unit` points wide standing on the desk at `desk`.
    static func camera(unit: CGFloat, desk: CGFloat) -> DeskCamera {
        .init(scale: unit / panelWidth, center: unit / 2, desk: desk, distance: cameraDistance, eyeHeight: cameraHeight)
    }

    /// The room needed under the foot for what lies on the desk up to `depth` centimetres in front
    /// of the panel.
    static func frontBand(depth: CGFloat) -> CGFloat {
        guard depth > 0 else { return 0 }
        let camera: DeskCamera = .init(scale: 1 / panelWidth, center: 0.5, desk: 0, distance: cameraDistance, eyeHeight: cameraHeight)
        let lowest: CGFloat = camera.point(x: 0, height: 0, depth: depth).y + 0.3 / panelWidth
        return max(0, lowest - (footHeight - sole))
    }
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

/// The Thunderbolt cable of the Mac: it hangs straight from the back of the panel beside the arm,
/// rests on the front edge of the plate of the foot, falls onto the desk in front of it and runs
/// to the Mac, behind which it ends. `side` is the side of the arm it hangs on (1 right, -1 left),
/// which animates: it slips behind the arm, drawn over it.
private struct XDRCable: View, Animatable {
    var side: CGFloat
    let center: CGFloat
    /// From the middle of the arm to the cable, as it hangs.
    let hang: CGFloat
    /// Where it leaves the back of the panel, the front edge of the plate and the desk, from the top.
    let top: CGFloat
    let plate: CGFloat
    let desk: CGFloat
    /// Behind the Mac, across, and the Mac itself.
    let end: CGFloat
    let mac: ClosedRange<CGFloat>
    let width: CGFloat

    nonisolated var animatableData: CGFloat {
        get { side }
        set { side = newValue }
    }

    var body: some View {
        let x: CGFloat = center + side * hang
        // Toward the Mac, on the desk.
        let toward: CGFloat = end >= x ? 1 : -1
        // In front of the plate, on the desk, a little lower than its sole; straight behind the Mac
        // when it stands in front of where the cable falls.
        let isBehindMac: Bool = x >= mac.lowerBound - width * 3 && x <= mac.upperBound + width * 3
        let front: CGFloat = isBehindMac ? desk - width * 2 : desk + width * 0.9
        let path: Path = .init { path in
            path.move(to: .init(x: x, y: top))
            path.addLine(to: .init(x: x, y: plate - width))
            // Over the rounded front edge of the plate, and down its face onto the desk.
            path.addCurve(
                to: .init(x: x + toward * width * 2.5, y: front),
                control1: .init(x: x + toward * width * 0.6, y: plate + width * 0.4),
                control2: .init(x: x + toward * width * 0.4, y: front)
            )
            // Along the desk, then behind the Mac.
            path.addCurve(
                to: .init(x: end, y: desk - width * 2),
                control1: .init(x: x + (end - x) * 0.6, y: front),
                control2: .init(x: end - (end - x) * 0.15, y: front)
            )
        }
        ZStack {
            path.stroke(Color(white: 0.09), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
            // The light along its braid.
            path.stroke(Color(white: 0.34), style: StrokeStyle(lineWidth: width * 0.28, lineCap: .round, lineJoin: .round))
                .offset(x: -width * 0.22, y: -width * 0.15)
        }
        .allowsHitTesting(false)
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
