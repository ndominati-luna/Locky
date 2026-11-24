import SwiftUI

/// The fireworks that open the Mac lab the first time: rockets in the colours of Locky that burst
/// into stars around its logo, five seconds long. One programme for the picture
/// (``LockyFireworks``) and the hand (``FireworksHaptics``), so that every burst is felt as it is
/// seen.
enum FireworksShow {
    struct Rocket {
        /// When it leaves the ground, in seconds.
        let launch: Double
        /// Where it leaves from and where it bursts, in fractions of the screen.
        let start: CGFloat
        let burst: CGPoint
        /// The colours of its stars, the first one most of them.
        let colours: [Color]
        let stars: Int
        /// The finale: wider, louder.
        let isBig: Bool
        /// For the scatter of its stars, the same each time.
        let seed: UInt64

        var burstTime: Double {
            launch + FireworksShow.flight
        }

        /// The same rocket on the other side of the screen, its stars scattered anew.
        func mirrored(round: Int) -> Rocket {
            .init(
                launch: launch,
                start: 1 - start,
                burst: .init(x: 1 - burst.x, y: burst.y),
                colours: colours,
                stars: stars,
                isBig: isBig,
                seed: seed &+ UInt64(round) &* 131
            )
        }
    }

    /// The programme, once: the first five seconds, felt in the hand.
    static let duration: Double = 5
    /// Then it starts again, every so often, for as long as the congratulations stay on screen.
    static let cycle: Double = 4.2
    /// From the ground to the burst.
    static let flight: Double = 0.65
    /// How long its stars shine.
    static let life: Double = 1.35

    static let blue: Color = .init(.sRGB, red: 0.12, green: 0.53, blue: 0.96)
    static let sky: Color = .init(.sRGB, red: 0.56, green: 0.82, blue: 1)
    static let gold: Color = .init(.sRGB, red: 1, green: 0.84, blue: 0.36)
    static let white: Color = .white

    static let rockets: [Rocket] = [
        .init(launch: 0.1, start: 0.3, burst: .init(x: 0.26, y: 0.24), colours: [blue, white], stars: 30, isBig: false, seed: 11),
        .init(launch: 0.5, start: 0.72, burst: .init(x: 0.74, y: 0.2), colours: [gold, white], stars: 30, isBig: false, seed: 23),
        .init(launch: 0.9, start: 0.5, burst: .init(x: 0.5, y: 0.13), colours: [sky, blue], stars: 34, isBig: false, seed: 37),
        .init(launch: 1.3, start: 0.18, burst: .init(x: 0.17, y: 0.38), colours: [white, gold], stars: 28, isBig: false, seed: 41),
        .init(launch: 1.65, start: 0.84, burst: .init(x: 0.83, y: 0.36), colours: [blue, sky], stars: 28, isBig: false, seed: 53),
        .init(launch: 2.0, start: 0.4, burst: .init(x: 0.36, y: 0.16), colours: [gold, blue], stars: 32, isBig: false, seed: 67),
        .init(launch: 2.35, start: 0.62, burst: .init(x: 0.66, y: 0.27), colours: [white, sky], stars: 32, isBig: false, seed: 71),
        // The finale, three at once.
        .init(launch: 2.9, start: 0.22, burst: .init(x: 0.24, y: 0.2), colours: [blue, white, gold], stars: 42, isBig: true, seed: 83),
        .init(launch: 3.0, start: 0.78, burst: .init(x: 0.76, y: 0.22), colours: [gold, white, blue], stars: 42, isBig: true, seed: 97),
        .init(launch: 3.12, start: 0.5, burst: .init(x: 0.5, y: 0.1), colours: [sky, white, gold], stars: 48, isBig: true, seed: 101)
    ]

    /// Numbers that look random, the same for the same seed.
    struct Scatter {
        private var state: UInt64

        init(seed: UInt64) {
            state = seed &* 0x9E37_79B9_7F4A_7C15
        }

        /// Between 0 and 1.
        mutating func next() -> Double {
            state &+= 0x9E37_79B9_7F4A_7C15
            var value: UInt64 = state
            value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
            value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
            value ^= value >> 31
            return Double(value >> 11) / Double(1 << 53)
        }

        mutating func next(in range: ClosedRange<Double>) -> Double {
            range.lowerBound + next() * (range.upperBound - range.lowerBound)
        }
    }
}
