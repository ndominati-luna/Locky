import SwiftUI

/// What the hands do to a Pro Display XDR, whatever the device: turn it (two fingers twisting, or
/// the trackpad), lift it along its stand (two fingers moving, or a two-finger scroll on the Mac),
/// tilt or swivel its panel (one finger, or a drag with the mouse), and put it back as it came (a
/// double tap, or a double click). Each gesture reports its progress from where it began, then its
/// end.
struct ProDisplayXDRGestureHandlers {
    /// Where two fingers came down, before they twist or move (on the iPhone).
    var twoFingersBegan: (CGPoint) -> Void
    var turnChanged: (Angle) -> Void
    var turnEnded: (Angle) -> Void
    /// Two fingers moving on the iPhone, points as they go.
    var panChanged: (CGSize) -> Void
    var panEnded: (CGSize) -> Void
    /// Two fingers spreading (above 1) or closing side to side on the iPhone.
    var pinchChanged: (CGFloat) -> Void
    var pinchEnded: (CGFloat) -> Void
    /// A two-finger scroll on the Mac, points, positive up.
    var liftChanged: (CGFloat) -> Void
    var liftEnded: (CGFloat) -> Void
    /// Where one finger came down, before it moves (on the iPhone).
    var oneFingerBegan: (CGPoint) -> Void
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
/// The UIKit recognizers of the hands (``HandPanRecognizer`` and its siblings): they also see the
/// touches made on the player of the film (a UIKit view), recognize together (twist and lift with
/// the same two fingers), and keep a page from scrolling while the display is handled. A disabled
/// display lets the touches go by.
private struct ProDisplayXDRGesturesModifier: ViewModifier {
    let handlers: ProDisplayXDRGestureHandlers

    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        content
            .gesture(
                HandRotationRecognizer(isEnabled: isEnabled, began: handlers.twoFingersBegan, changed: handlers.turnChanged, ended: handlers.turnEnded)
            )
            .gesture(
                HandPanRecognizer(touches: 2, isEnabled: isEnabled, began: handlers.twoFingersBegan, changed: handlers.panChanged, ended: handlers.panEnded)
            )
            .gesture(
                HandPinchRecognizer(isEnabled: isEnabled, began: handlers.twoFingersBegan, changed: handlers.pinchChanged, ended: handlers.pinchEnded)
            )
            .gesture(HandPanRecognizer(touches: 1, isEnabled: isEnabled, began: handlers.oneFingerBegan, changed: handlers.leanChanged, ended: handlers.leanEnded))
            .gesture(HandDoubleTapRecognizer(isEnabled: isEnabled, tapped: handlers.reset))
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
