import SwiftUI

/// What the hands do to a Pro Display XDR, whatever the device: turn it (two fingers twisting, or
/// the trackpad), lift it along its stand (two fingers moving, or a two-finger scroll on the Mac),
/// and tilt or swivel its panel (one finger, or a drag with the mouse). Each gesture reports its progress
/// from where it began, then its end.
struct ProDisplayXDRGestureHandlers {
    var turnChanged: (Angle) -> Void
    var turnEnded: (Angle) -> Void
    /// Points, positive up.
    var liftChanged: (CGFloat) -> Void
    var liftEnded: (CGFloat) -> Void
    /// Points, as the finger or the mouse moves.
    var leanChanged: (CGSize) -> Void
    var leanEnded: (CGSize) -> Void
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
    }
}

/// Lets the recognizers of the display work together, and makes a scroll view under them wait.
private final class XDRRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    static let name: String = "ProDisplayXDR"

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer.name == Self.name
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        otherGestureRecognizer.view is UIScrollView
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
#elseif os(macOS)
import AppKit

/// The trackpad turns the display, a two-finger scroll over it lifts it, a drag tilts and swivels
/// it (the player of the film keeps the clicks made on the picture: drag the frame or the stand).
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
                XDRScrollWatcher(changed: handlers.liftChanged, ended: handlers.liftEnded)
            }
    }
}

/// Follows the two-finger scrolls made over the display (SwiftUI has no gesture for them) and keeps
/// them from scrolling anything else.
private struct XDRScrollWatcher: NSViewRepresentable {
    let changed: (CGFloat) -> Void
    let ended: (CGFloat) -> Void

    func makeNSView(context: Context) -> WatchingView {
        let view: WatchingView = .init()
        view.changed = changed
        view.ended = ended
        return view
    }

    func updateNSView(_ view: WatchingView, context: Context) {
        view.changed = changed
        view.ended = ended
    }

    final class WatchingView: NSView {
        var changed: (CGFloat) -> Void = { _ in }
        var ended: (CGFloat) -> Void = { _ in }
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
            monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, event.window == self.window else { return event }
                return self.handle(event) ? nil : event
            }
        }

        /// Takes the scroll when it happens over the display.
        private func handle(_ event: NSEvent) -> Bool {
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
