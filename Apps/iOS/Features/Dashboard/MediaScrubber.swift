import SwiftUI

/// A bar like the Now Playing controls of iOS: no thumb, the filled part follows the finger and the
/// bar thickens while touched. The finger moves the value from where it was, it does not jump to
/// where the bar is touched. Plain black or white: on glass, semantic colors (even `Color.primary`)
/// take the tint of the background and wash the bar out. VoiceOver sees a regular slider.
struct MediaScrubber: View {
    /// From 0 to 1.
    @Binding var value: Double
    let accessibilityLabel: Text
    /// Bright while it controls something playing, faded otherwise.
    var isProminent: Bool = true
    /// `true` while the finger is on the bar, `false` once it leaves.
    var onEditingChanged: (Bool) -> Void = { _ in }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.colorScheme) private var colorScheme
    @State private var dragStartValue: Double?
    @State private var width: CGFloat = 1

    private var isDragging: Bool {
        dragStartValue != nil
    }

    var body: some View {
        Capsule()
            .fill(ink.opacity(isProminent ? 0.25 : 0.12))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(ink.opacity(isProminent ? 1 : 0.5))
                    .frame(width: width * min(max(value, 0), 1))
            }
            .clipShape(.capsule)
            .frame(height: isDragging ? 12 : 6)
            // A taller area to touch than the bar.
            .frame(height: 28)
            .contentShape(.rect)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = max($0, 1) }
            .gesture(drag, isEnabled: isEnabled)
            .animation(.smooth(duration: 0.2), value: isDragging)
            .accessibilityRepresentation {
                Slider(value: $value, in: 0...1) { editing in
                    onEditingChanged(editing)
                }
                .accessibilityLabel(accessibilityLabel)
            }
    }

    private var ink: Color {
        colorScheme == .dark ? .white : .black
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                if dragStartValue == nil {
                    dragStartValue = value
                    onEditingChanged(true)
                }
                let start: Double = dragStartValue ?? value
                value = min(max(start + gesture.translation.width / width, 0), 1)
            }
            .onEnded { _ in
                dragStartValue = nil
                onEditingChanged(false)
            }
    }
}
