import SwiftUI

/// Measures the window around the root view and follows the hinge to publish ``ScreenFold`` in
/// the environment. Applied once, at the root of the app (whose frame is the safe area of the
/// window).
struct ScreenFoldReader: ViewModifier {
    @State private var window: WindowGeometry?
    @State private var isHalfOpen: Bool = false

    func body(content: Content) -> some View {
        content
            .environment(\.screenFold, fold)
            .environment(\.isLargeScreen, isLargeScreen)
            .onGeometryChange(for: WindowGeometry.self) { proxy in
                // The root view covers the safe area; its insets give back the whole window.
                let insets: EdgeInsets = proxy.safeAreaInsets
                return .init(
                    size: .init(
                        width: proxy.size.width + insets.leading + insets.trailing,
                        height: proxy.size.height + insets.top + insets.bottom
                    ),
                    safeAreaOrigin: .init(x: insets.leading, y: insets.top)
                )
            } action: { newWindow in
                window = newWindow
            }
            .modifier(HingeReader(isHalfOpen: $isHalfOpen))
            // Folding or unfolding switches between one screen and two pages: cross-fade.
            .animation(.smooth(duration: 0.35), value: isHalfOpen)
    }

    private var isLargeScreen: Bool {
        window.map { min($0.size.width, $0.size.height) >= ScreenFold.minimumShortSide } ?? false
    }

    private var fold: ScreenFold? {
        window.flatMap { ScreenFold.detect(windowSize: $0.size, safeAreaOrigin: $0.safeAreaOrigin, isHalfOpen: isHalfOpen) }
    }
}

private struct WindowGeometry: Equatable {
    var size: CGSize
    var safeAreaOrigin: CGPoint
}

/// Whether the hinge of a foldable iPhone is half open (iOS 27.1 and later). Flat when unknown.
private struct HingeReader: ViewModifier {
    @Binding var isHalfOpen: Bool

    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.onHingeChange { _, context in
                isHalfOpen = context.hinge?.status == .partiallyOpen
            }
        } else {
            content
        }
    }
}

extension View {
    /// Publishes the fold of the screen (see ``ScreenFold``) to the views below.
    func readScreenFold() -> some View {
        modifier(ScreenFoldReader())
    }
}
