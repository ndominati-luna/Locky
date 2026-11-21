import SwiftUI

/// A bar like the Now Playing controls of iOS: no thumb, the filled part follows the finger and the
/// bar thickens while touched. The finger moves the value from where it was, it does not jump to
/// where the bar is touched. VoiceOver sees a regular slider.
struct MediaScrubber: View {
    /// From 0 to 1.
    @Binding var value: Double
    let accessibilityLabel: Text
    /// `true` while the finger is on the bar, `false` once it leaves.
    var onEditingChanged: (Bool) -> Void = { _ in }

    @Environment(\.isEnabled) private var isEnabled
    @State private var dragStartValue: Double?
    @State private var width: CGFloat = 1

    private var isDragging: Bool {
        dragStartValue != nil
    }

    var body: some View {
        Capsule()
            .fill(Color.primary.opacity(0.2))
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Color.primary)
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
