import SwiftUI

/// Twinkling stars around an illustration (the "magic" of the original onboarding).
struct SparklesView: View {
    var isActive: Bool = true

    private struct Sparkle {
        let resource: ImageResource
        let position: UnitPoint
        let size: CGFloat
        let delay: Double
    }

    private let sparkles: [Sparkle] = [
        .init(resource: .bigStar4, position: .init(x: 0.12, y: 0.18), size: 30, delay: 0),
        .init(resource: .star4, position: .init(x: 0.88, y: 0.12), size: 26, delay: 0.7),
        .init(resource: .smallStar4, position: .init(x: 0.82, y: 0.78), size: 22, delay: 1.3),
        .init(resource: .star4, position: .init(x: 0.08, y: 0.7), size: 20, delay: 1.9),
        .init(resource: .bigStar4, position: .init(x: 0.95, y: 0.45), size: 18, delay: 2.4),
        .init(resource: .smallStar4, position: .init(x: 0.3, y: 0.02), size: 16, delay: 0.4)
    ]

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { timeline in
            let time: Double = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                for sparkle in sparkles {
                    let wave: Double = (sin((time + sparkle.delay) * 2.1) + 1) / 2
                    guard let symbol = context.resolveSymbol(id: sparkle.delay) else { continue }
                    var star: GraphicsContext = context
                    star.opacity = 0.25 + wave * 0.75
                    let scale: Double = 0.6 + wave * 0.5
                    let center: CGPoint = .init(x: sparkle.position.x * size.width, y: sparkle.position.y * size.height)
                    star.translateBy(x: center.x, y: center.y)
                    star.scaleBy(x: scale, y: scale)
                    star.draw(symbol, at: .zero)
                }
            } symbols: {
                ForEach(sparkles, id: \.delay) { sparkle in
                    Image(sparkle.resource)
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color.brandArt)
                        .frame(width: sparkle.size, height: sparkle.size)
                        .tag(sparkle.delay)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
