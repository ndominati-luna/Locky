import SwiftUI

/// What the hands do to a Pro Display XDR, whatever the device: turn it (two fingers twisting, or
/// the trackpad), lift it along its stand (two fingers moving, or a two-finger scroll on the Mac),
/// tilt or swivel its panel (one finger, or a drag with the mouse), and put it back as it came (a
/// double tap, or a double click). Each gesture reports its progress from where it began, then its
/// end.
struct ProDisplayXDRGestureHandlers {
    var turnChanged: (Angle) -> Void
    var turnEnded: (Angle) -> Void
    /// Points, positive up.
    var liftChanged: (CGFloat) -> Void
    var liftEnded: (CGFloat) -> Void
    /// Points, as the finger or the mouse moves.
    var leanChanged: (CGSize) -> Void
    var leanEnded: (CGSize) -> Void
    var reset: () -> Void
}

extension View {
    /// The gestures of a Pro Display XDR, implicit, on the whole display (over a video too).
    func proDisplayXDRGestures(_ handlers: ProDisplayXDRGestureHandlers) -> some View {
        modifier(ProDisplayXDRGesturesModifier(handlers: handlers))
    }
}

#if os(iOS)
import UIKit

/// UIKit recognizers rather than SwiftUI gestures: they also see the touches made on the player of
/// the film (a UIKit view), recognize together (twist and lift with the same two fingers), and keep
/// a page from scrolling while the display is handled.
private struct ProDisplayXDRGesturesModifier: ViewModifier {
    let handlers: ProDisplayXDRGestureHandlers

    func body(content: Content) -> some View {
        content
            .gesture(XDRRotationRecognizer(changed: handlers.turnChanged, ended: handlers.turnEnded))
            .gesture(XDRPanRecognizer(touches: 2) { handlers.liftChanged(-$0.height) } ended: { handlers.liftEnded(-$0.height) })
            .gesture(XDRPanRecognizer(touches: 1, changed: handlers.leanChanged, ended: handlers.leanEnded))
            .gesture(XDRDoubleTapRecognizer(tapped: handlers.reset))
    }
}

/// Lets the recognizers of the display work together, makes a scroll view under them wait, and the
/// taps of the player of the film wait for the double tap.
private final class XDRRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    static let name: String = "ProDisplayXDR"

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // The double tap only watches: the player must not make it fail.
        otherGestureRecognizer.name == Self.name || gestureRecognizer is XDRDoubleTapGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer.view is UIScrollView {
            return true
        }
        // The taps of the player (its controls, play or pause in the middle) wait to know whether a
        // second tap follows.
        return gestureRecognizer is XDRDoubleTapGestureRecognizer
            && (otherGestureRecognizer as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
    }
}

private struct XDRRotationRecognizer: UIGestureRecognizerRepresentable {
    let changed: (Angle) -> Void
    let ended: (Angle) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> XDRRecognizerDelegate {
        .init()
    }

    func makeUIGestureRecognizer(context: Context) -> UIRotationGestureRecognizer {
        let recognizer: UIRotationGestureRecognizer = .init()
        recognizer.name = XDRRecognizerDelegate.name
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIRotationGestureRecognizer, context: Context) {
        let angle: Angle = .radians(Double(recognizer.rotation))
        switch recognizer.state {
        case .began, .changed:
            changed(angle)
        case .ended, .cancelled, .failed:
            ended(angle)
        default:
            break
        }
    }
}

private struct XDRPanRecognizer: UIGestureRecognizerRepresentable {
    let touches: Int
    let changed: (CGSize) -> Void
    let ended: (CGSize) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> XDRRecognizerDelegate {
        .init()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer: UIPanGestureRecognizer = .init()
        recognizer.minimumNumberOfTouches = touches
        recognizer.maximumNumberOfTouches = touches
        recognizer.name = XDRRecognizerDelegate.name
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let point: CGPoint = recognizer.translation(in: recognizer.view)
        let translation: CGSize = .init(width: point.x, height: point.y)
        switch recognizer.state {
        case .began, .changed:
            changed(translation)
        case .ended, .cancelled, .failed:
            ended(translation)
        default:
            break
        }
    }
}

/// Two taps put the display back as it came.
private struct XDRDoubleTapRecognizer: UIGestureRecognizerRepresentable {
    let tapped: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> XDRRecognizerDelegate {
        .init()
    }

    func makeUIGestureRecognizer(context: Context) -> XDRDoubleTapGestureRecognizer {
        let recognizer: XDRDoubleTapGestureRecognizer = .init()
        // The buttons of the player answer a single tap at once, as without the display.
        recognizer.delaysTouchesEnded = false
        recognizer.name = XDRRecognizerDelegate.name
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: XDRDoubleTapGestureRecognizer, context: Context) {
        if recognizer.state == .ended {
            tapped()
        }
    }
}

/// Two quick taps of one finger at the same place. Over the film, the taps of the player (its
/// controls, play or pause in the middle) wait for it to fail, and once recognized it takes the
/// second tap from the button under the finger: a double tap never pauses nor skips the film. Its
/// own recognizer rather than a `UITapGestureRecognizer`, for its delay is how long the player waits.
private final class XDRDoubleTapGestureRecognizer: UIGestureRecognizer {
    private static let maximumDelay: Duration = .milliseconds(350)
    private static let maximumPress: TimeInterval = 0.4
    private static let slop: CGFloat = 12
    private static let maximumGap: CGFloat = 40

    /// Where the touch in progress began, in the window, and when.
    private var press: (location: CGPoint, time: TimeInterval)?
    /// Where the first tap was, waiting for the second.
    private var firstTap: CGPoint?
    private var expiry: Task<Void, Never>?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        guard touches.count == 1, event.allTouches?.count == 1, let touch = touches.first else {
            state = .failed
            return
        }
        expiry?.cancel()
        let location: CGPoint = touch.location(in: nil)
        if let firstTap, Self.distance(firstTap, location) > Self.maximumGap {
            state = .failed
            return
        }
        press = (location, touch.timestamp)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        guard let touch = touches.first, let press else { return }
        if Self.distance(press.location, touch.location(in: nil)) > Self.slop {
            state = .failed
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        guard let touch = touches.first, let press, touch.timestamp - press.time < Self.maximumPress else {
            state = .failed
            return
        }
        guard firstTap == nil else {
            state = .ended
            return
        }
        firstTap = press.location
        self.press = nil
        expiry = Task { [weak self] in
            try? await Task.sleep(for: Self.maximumDelay)
            guard let self, !Task.isCancelled, self.state == .possible else { return }
            self.state = .failed
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        state = .failed
    }

    override func reset() {
        super.reset()
        expiry?.cancel()
        expiry = nil
        press = nil
        firstTap = nil
    }

    private static func distance(_ first: CGPoint, _ second: CGPoint) -> CGFloat {
        hypot(second.x - first.x, second.y - first.y)
    }
}
#elseif os(macOS)
import AppKit

/// The trackpad turns the display, a two-finger scroll over it lifts it, a drag tilts and swivels
/// it (the player of the film keeps the clicks made on the picture: drag the frame or the stand), a
/// double click anywhere on it, the picture too, puts it back.
private struct ProDisplayXDRGesturesModifier: ViewModifier {
    let handlers: ProDisplayXDRGestureHandlers

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                RotateGesture()
                    .onChanged { handlers.turnChanged($0.rotation) }
                    .onEnded { handlers.turnEnded($0.rotation) }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { handlers.leanChanged($0.translation) }
                    .onEnded { handlers.leanEnded($0.translation) }
            )
            .background {
                XDREventWatcher(liftChanged: handlers.liftChanged, liftEnded: handlers.liftEnded, doubleClicked: handlers.reset)
            }
    }
}

/// Follows the two-finger scrolls made over the display (SwiftUI has no gesture for them) and keeps
/// them from scrolling anything else; sees the double clicks made on it, over the player of the film
/// too, which keeps its clicks.
private struct XDREventWatcher: NSViewRepresentable {
    let liftChanged: (CGFloat) -> Void
    let liftEnded: (CGFloat) -> Void
    let doubleClicked: () -> Void

    func makeNSView(context: Context) -> WatchingView {
        let view: WatchingView = .init()
        updateNSView(view, context: context)
        return view
    }

    func updateNSView(_ view: WatchingView, context: Context) {
        view.changed = liftChanged
        view.ended = liftEnded
        view.doubleClicked = doubleClicked
    }

    final class WatchingView: NSView {
        var changed: (CGFloat) -> Void = { _ in }
        var ended: (CGFloat) -> Void = { _ in }
        var doubleClicked: () -> Void = {}
        private var monitor: Any?
        private var lift: CGFloat = 0

        /// Never in the way of the clicks: it only watches.
        override func hitTest(_ point: NSPoint) -> NSView? {
            nil
        }

        isolated deinit {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let monitor {
                NSEvent.removeMonitor(monitor)
                self.monitor = nil
            }
            guard window != nil else { return }
            monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .leftMouseDown]) { [weak self] event in
                guard let self, event.window == self.window else { return event }
                if event.type == .leftMouseDown {
                    self.click(event)
                    return event
                }
                return self.scroll(event) ? nil : event
            }
        }

        /// The second click of a double click over the display; the click goes on to the display.
        private func click(_ event: NSEvent) {
            guard event.clickCount == 2, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
            doubleClicked()
        }

        /// Takes the scroll when it happens over the display.
        private func scroll(_ event: NSEvent) -> Bool {
            let point: NSPoint = convert(event.locationInWindow, from: nil)
            let isGesture: Bool = !event.phase.isEmpty || !event.momentumPhase.isEmpty
            guard bounds.contains(point) || (isGesture && lift != 0) else { return false }
            // Fingers up lift the display, whatever the direction of scrolling of the Mac.
            let fingersUp: CGFloat = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY : event.scrollingDeltaY
            if event.momentumPhase.isEmpty {
                lift += fingersUp
                changed(lift)
            }
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) || !isGesture {
                ended(lift)
                lift = 0
            }
            return true
        }
    }
}
#endif
