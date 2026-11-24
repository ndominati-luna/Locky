#if os(iOS)
import SwiftUI
import UIKit

// The recognizers behind the implicit gestures of the drawn devices (the Pro Display XDR, the lid
// of a MacBook): UIKit rather than SwiftUI gestures, for they count the fingers, recognize
// together (twist and lift with the same two fingers), see the touches made on a UIKit view under
// them (the player of a film), and keep a page from scrolling while a device is handled. They all
// follow `\.isEnabled`: a disabled device lets the touches go by.

/// Lets the recognizers of a device work together, makes a scroll view under them wait, and the
/// single taps of a player wait for the double tap.
class HandRecognizerDelegate: NSObject, UIGestureRecognizerDelegate {
    static let name: String = "LockyHands"

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // The double tap only watches: a player must not make it fail.
        otherGestureRecognizer.name == Self.name || gestureRecognizer is HandDoubleTapGestureRecognizer
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if otherGestureRecognizer.view is UIScrollView {
            return true
        }
        // The taps of a player (its controls, play or pause in the middle) wait to know whether a
        // second tap follows.
        return gestureRecognizer is HandDoubleTapGestureRecognizer
            && (otherGestureRecognizer as? UITapGestureRecognizer)?.numberOfTapsRequired == 1
    }
}

/// Two fingers twisting: where they were when they began to, the angle since they came down, then
/// the end.
struct HandRotationRecognizer: UIGestureRecognizerRepresentable {
    var isEnabled: Bool = true
    var began: (CGPoint) -> Void = { _ in }
    let changed: (Angle) -> Void
    let ended: (Angle) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> HandRecognizerDelegate {
        .init()
    }

    func makeUIGestureRecognizer(context: Context) -> UIRotationGestureRecognizer {
        let recognizer: UIRotationGestureRecognizer = .init()
        recognizer.name = HandRecognizerDelegate.name
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIRotationGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIRotationGestureRecognizer, context: Context) {
        let angle: Angle = .radians(Double(recognizer.rotation))
        switch recognizer.state {
        case .began:
            began(context.converter.location(in: .local))
            changed(angle)
        case .changed:
            changed(angle)
        case .ended, .cancelled, .failed:
            ended(angle)
        default:
            break
        }
    }
}

/// Exactly `touches` fingers moving together: where they were when they began to move (between
/// them), their translation since, then the end.
struct HandPanRecognizer: UIGestureRecognizerRepresentable {
    let touches: Int
    var isEnabled: Bool = true
    var began: (CGPoint) -> Void = { _ in }
    let changed: (CGSize) -> Void
    let ended: (CGSize) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> HandRecognizerDelegate {
        .init()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let recognizer: UIPanGestureRecognizer = .init()
        recognizer.minimumNumberOfTouches = touches
        recognizer.maximumNumberOfTouches = touches
        recognizer.name = HandRecognizerDelegate.name
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        let point: CGPoint = recognizer.translation(in: recognizer.view)
        let translation: CGSize = .init(width: point.x, height: point.y)
        switch recognizer.state {
        case .began:
            began(context.converter.location(in: .local))
            changed(translation)
        case .changed:
            changed(translation)
        case .ended, .cancelled, .failed:
            ended(translation)
        default:
            break
        }
    }
}

/// Two fingers spreading or closing side to side: where they were when they began to, how many
/// times wider apart across they are since (above 1 spread, below closed), then the end. Only the
/// horizontal gap between them counts.
struct HandPinchRecognizer: UIGestureRecognizerRepresentable {
    var isEnabled: Bool = true
    var began: (CGPoint) -> Void = { _ in }
    let changed: (CGFloat) -> Void
    let ended: (CGFloat) -> Void

    /// The gap the fingers began with, and the last ratio, kept for the end (one finger may
    /// already be gone).
    final class Coordinator: HandRecognizerDelegate {
        var start: CGFloat = 1
        var ratio: CGFloat = 1
    }

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        .init()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPinchGestureRecognizer {
        let recognizer: UIPinchGestureRecognizer = .init()
        recognizer.name = HandRecognizerDelegate.name
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIPinchGestureRecognizer, context: Context) {
        /// The horizontal gap between the two fingers, while both are down.
        func gap() -> CGFloat? {
            guard recognizer.numberOfTouches >= 2 else { return nil }
            return abs(recognizer.location(ofTouch: 0, in: recognizer.view).x - recognizer.location(ofTouch: 1, in: recognizer.view).x)
        }
        switch recognizer.state {
        case .began:
            // Recognized once the fingers have moved a little: the gap they began with, about.
            context.coordinator.start = max((gap() ?? 0) / max(recognizer.scale, 0.01), 24)
            context.coordinator.ratio = (gap() ?? context.coordinator.start) / context.coordinator.start
            began(context.converter.location(in: .local))
            changed(context.coordinator.ratio)
        case .changed:
            if let gap = gap() {
                context.coordinator.ratio = gap / context.coordinator.start
            }
            changed(context.coordinator.ratio)
        case .ended, .cancelled, .failed:
            ended(context.coordinator.ratio)
        default:
            break
        }
    }
}

/// Two quick taps of one finger.
struct HandDoubleTapRecognizer: UIGestureRecognizerRepresentable {
    var isEnabled: Bool = true
    let tapped: () -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> HandRecognizerDelegate {
        .init()
    }

    func makeUIGestureRecognizer(context: Context) -> HandDoubleTapGestureRecognizer {
        let recognizer: HandDoubleTapGestureRecognizer = .init()
        // The buttons of a player answer a single tap at once, as without the device around it.
        recognizer.delaysTouchesEnded = false
        recognizer.name = HandRecognizerDelegate.name
        recognizer.delegate = context.coordinator
        return recognizer
    }

    func updateUIGestureRecognizer(_ recognizer: HandDoubleTapGestureRecognizer, context: Context) {
        recognizer.isEnabled = isEnabled
    }

    func handleUIGestureRecognizerAction(_ recognizer: HandDoubleTapGestureRecognizer, context: Context) {
        if recognizer.state == .ended {
            tapped()
        }
    }
}

/// Two quick taps of one finger at the same place. Over a film, the taps of the player (its
/// controls, play or pause in the middle) wait for it to fail, and once recognized it takes the
/// second tap from the button under the finger: a double tap never pauses nor skips the film. Its
/// own recognizer rather than a `UITapGestureRecognizer`, for its delay is how long the player waits.
final class HandDoubleTapGestureRecognizer: UIGestureRecognizer {
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
#endif
