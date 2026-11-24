import SwiftUI

/// The arrow of macOS on the screen of a drawn Mac, black edged with white, its tip at `position`
/// (fractions of the screen), shown while a finger plays on the trackpad on the desk.
struct MacCursor: View {
    let position: CGPoint

    var body: some View {
        GeometryReader { proxy in
            let height: CGFloat = max(proxy.size.width * 0.04, 9)
            CursorArrow()
                .fill(.black)
                .overlay {
                    CursorArrow()
                        .stroke(.white, style: StrokeStyle(lineWidth: height * 0.07, lineJoin: .round))
                }
                .frame(width: height * 11 / 18, height: height)
                .shadow(color: .black.opacity(0.35), radius: height * 0.08, y: height * 0.05)
                .offset(x: position.x * proxy.size.width, y: position.y * proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The arrow, its tip at the top left corner.
private struct CursorArrow: Shape {
    func path(in rect: CGRect) -> Path {
        // On a grid 11 wide and 18 high, as macOS draws it.
        let points: [CGPoint] = [
            .init(x: 0, y: 0),
            .init(x: 0, y: 15.5),
            .init(x: 3.8, y: 12),
            .init(x: 6.4, y: 18),
            .init(x: 8.6, y: 17),
            .init(x: 6.1, y: 11.2),
            .init(x: 11, y: 11.2)
        ]
        var path: Path = .init()
        path.addLines(points.map { CGPoint(x: rect.minX + $0.x / 11 * rect.width, y: rect.minY + $0.y / 18 * rect.height) })
        path.closeSubpath()
        return path
    }
}
