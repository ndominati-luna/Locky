import SwiftUI

/// The fireworks that open the Mac Lab the first time (``FireworksShow``): rockets that burst into
/// stars all around the logo of Locky, which spreads its wings, and the congratulations. The first
/// five seconds are felt in the hand too; the fireworks then go on, as long as one likes, until the
/// button that enters the lab (`finished`).
struct LockyFireworks: View {
    let finished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start: Date = .now
    @State private var haptics: FireworksHaptics = .init()
    @State private var areWingsSpread: Bool = false
    @State private var isLockIn: Bool = false
    @State private var isTextShown: Bool = false
    @State private var isButtonShown: Bool = false
    @State private var isFadingOut: Bool = false

    var body: some View {
        ZStack {
            // The app behind, blurred and darkened: the night sky of the fireworks.
            Rectangle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .overlay(Color.black.opacity(0.45))
                .ignoresSafeArea()
            TimelineView(.animation) { timeline in
                let time: Double = timeline.date.timeIntervalSince(start)
                Canvas { context, size in
                    FireworksPainter(time: time, size: size).paint(in: &context)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    Image(.lockyWings)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(x: areWingsSpread ? 1 : 0.2, y: areWingsSpread ? 1 : 0.6)
                        .opacity(areWingsSpread ? 1 : 0)
                    Image(.lockyLock)
                        .resizable()
                        .scaledToFit()
                        .offset(y: isLockIn ? 0 : -160)
                        .opacity(isLockIn ? 1 : 0)
                }
                .foregroundStyle(.white)
                .frame(width: 180, height: 180)
                .shadow(color: FireworksShow.sky.opacity(0.9), radius: 24)
                .shadow(color: FireworksShow.blue.opacity(0.8), radius: 48)

                VStack(spacing: 10) {
                    Text("Congratulations!")
                        .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    Text("You unlocked the Mac Lab: every Mac of Locky, with the wallpaper of your choice.")
                        .font(.title3.weight(.semibold))
                    Text("From now on, a single shake of your iPhone brings you back.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                }
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 8, y: 2)
                .padding(.horizontal, 32)
                .opacity(isTextShown ? 1 : 0)
                .scaleEffect(isTextShown ? 1 : 0.85)
                .accessibilityElement(children: .combine)

                // Under the congratulations, no bigger than their text.
                Button(action: enter) {
                    Text("Enter the Mac Lab")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(FireworksShow.blue)
                .controlSize(.regular)
                .opacity(isButtonShown ? 1 : 0)
                .scaleEffect(isButtonShown ? 1 : 0.8)
                .allowsHitTesting(isButtonShown && !isFadingOut)
            }
            .accessibilityElement(children: .contain)
        }
        .opacity(isFadingOut ? 0 : 1)
        .task {
            start = .now
            haptics.play()
            withAnimation(.spring(duration: 0.8, bounce: 0.35).delay(0.2)) { areWingsSpread = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.5).delay(0.65)) { isLockIn = true }
            withAnimation(.spring(duration: 0.7, bounce: 0.3).delay(1.05)) { isTextShown = true }
            withAnimation(.spring(duration: 0.6, bounce: 0.35).delay(1.7)) { isButtonShown = true }
        }
        .onDisappear {
            haptics.stop()
        }
    }

    /// The fireworks fade away and the lab opens.
    private func enter() {
        haptics.stop()
        withAnimation(.easeIn(duration: 0.35)) { isFadingOut = true }
        Task {
            try? await Task.sleep(for: .milliseconds(350))
            finished()
        }
    }
}

/// Paints the rockets and their stars at `time` seconds into the show: the programme again and
/// again, every ``FireworksShow/cycle`` seconds, each time the other way round.
private struct FireworksPainter {
    let time: Double
    let size: CGSize

    func paint(in context: inout GraphicsContext) {
        let current: Int = max(0, Int(time / FireworksShow.cycle))
        // The previous round still falls while the next one rises.
        for round in max(0, current - 1)...current {
            let shift: Double = Double(round) * FireworksShow.cycle
            let isMirrored: Bool = round % 2 == 1
            for (index, original) in FireworksShow.rockets.enumerated() {
                let rocket: FireworksShow.Rocket = isMirrored ? original.mirrored(round: round) : original
                let age: Double = time - shift - rocket.launch
                guard age >= 0, age < FireworksShow.flight + FireworksShow.life else { continue }
                let burst: CGPoint = .init(x: rocket.burst.x * size.width, y: rocket.burst.y * size.height)
                if age < FireworksShow.flight {
                    paintRise(of: rocket, age: age, to: burst, index: index, in: &context)
                } else {
                    paintBurst(of: rocket, age: age - FireworksShow.flight, at: burst, in: &context)
                }
            }
        }
    }

    /// The rocket going up, slowing down, a trail of sparks behind it.
    private func paintRise(of rocket: FireworksShow.Rocket, age: Double, to burst: CGPoint, index: Int, in context: inout GraphicsContext) {
        let from: CGPoint = .init(x: rocket.start * size.width, y: size.height * 1.02)
        func position(_ age: Double) -> CGPoint {
            let progress: Double = min(max(age / FireworksShow.flight, 0), 1)
            let eased: CGFloat = CGFloat(1 - (1 - progress) * (1 - progress))
            return .init(x: from.x + (burst.x - from.x) * eased, y: from.y + (burst.y - from.y) * eased)
        }
        for spark in 0..<8 {
            let behind: Double = Double(spark) * 0.035
            guard age - behind >= 0 else { continue }
            let point: CGPoint = position(age - behind)
            let fade: Double = 1 - Double(spark) / 8
            context.opacity = fade * 0.9
            let radius: CGFloat = 2.6 * CGFloat(fade) + 0.6
            context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(spark == 0 ? .white : rocket.colours[0]))
        }
        context.opacity = 1
        let head: CGPoint = position(age)
        context.fill(Self.star(at: head, radius: 7, turn: age * 9 + Double(index)), with: .color(.white))
    }

    /// The burst: a flash, then stars flying out, slowing down, falling and fading as they twinkle.
    private func paintBurst(of rocket: FireworksShow.Rocket, age: Double, at center: CGPoint, in context: inout GraphicsContext) {
        guard age < FireworksShow.life else { return }
        let reach: CGFloat = min(size.width, size.height) * (rocket.isBig ? 0.36 : 0.24)
        if age < 0.3 {
            let flash: Double = 1 - age / 0.3
            let radius: CGFloat = reach * 0.35 * CGFloat(0.4 + age / 0.3)
            context.opacity = flash * 0.55
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .radialGradient(Gradient(colors: [.white, rocket.colours[0].opacity(0)]), center: center, startRadius: 0, endRadius: radius)
            )
        }
        var scatter: FireworksShow.Scatter = .init(seed: rocket.seed)
        let fade: Double = pow(max(0, 1 - age / FireworksShow.life), 1.3)
        /// Where a star flying out at `angle`, `speed` is, `age` seconds after the burst: fast at
        /// first, slowing down, then falling.
        func position(angle: Double, speed: CGFloat, age: Double) -> CGPoint {
            let spread: CGFloat = CGFloat(1 - exp(-3.4 * max(age, 0)))
            let fall: CGFloat = CGFloat(age * age) * size.height * 0.07
            return .init(
                x: center.x + CGFloat(cos(angle)) * reach * speed * spread,
                y: center.y + CGFloat(sin(angle)) * reach * speed * spread + fall
            )
        }
        // Light adds up, as in a night sky.
        context.blendMode = .plusLighter
        for star in 0..<rocket.stars {
            let angle: Double = Double(star) / Double(rocket.stars) * 2 * .pi + scatter.next(in: -0.12...0.12)
            let speed: CGFloat = CGFloat(scatter.next(in: 0.72...1))
            let colour: Color = rocket.colours[star % 3 == 0 ? 0 : star % rocket.colours.count]
            let twinkle: Double = 0.6 + 0.4 * sin(age * 22 + Double(star) * 1.7)
            let point: CGPoint = position(angle: angle, speed: speed, age: age)
            let radius: CGFloat = (rocket.isBig ? 9 : 7) * CGFloat(1 - 0.5 * age / FireworksShow.life)
            // Its streak, behind it.
            var streak: Path = .init()
            streak.move(to: position(angle: angle, speed: speed, age: age - 0.12))
            streak.addLine(to: point)
            context.opacity = fade * 0.55
            context.stroke(streak, with: .color(colour), style: StrokeStyle(lineWidth: radius * 0.32, lineCap: .round))
            // Its glow.
            context.opacity = fade * 0.5
            context.fill(
                Path(ellipseIn: CGRect(x: point.x - radius * 1.4, y: point.y - radius * 1.4, width: radius * 2.8, height: radius * 2.8)),
                with: .radialGradient(Gradient(colors: [colour, colour.opacity(0)]), center: point, startRadius: 0, endRadius: radius * 1.4)
            )
            // The star, a white heart in its colour.
            context.opacity = fade * twinkle
            context.fill(Self.star(at: point, radius: radius, turn: angle + age * 2), with: .color(colour))
            context.fill(Self.star(at: point, radius: radius * 0.45, turn: angle + age * 2), with: .color(.white))
        }
        context.blendMode = .normal
        context.opacity = 1
    }

    /// The four-pointed star of Locky.
    static func star(at center: CGPoint, radius: CGFloat, turn: Double) -> Path {
        var path: Path = .init()
        for point in 0..<4 {
            let angle: Double = turn + Double(point) * .pi / 2
            let tip: CGPoint = .init(x: center.x + CGFloat(cos(angle)) * radius, y: center.y + CGFloat(sin(angle)) * radius)
            let next: Double = angle + .pi / 2
            let nextTip: CGPoint = .init(x: center.x + CGFloat(cos(next)) * radius, y: center.y + CGFloat(sin(next)) * radius)
            if point == 0 {
                path.move(to: tip)
            }
            let waist: Double = angle + .pi / 4
            let control: CGPoint = .init(x: center.x + CGFloat(cos(waist)) * radius * 0.16, y: center.y + CGFloat(sin(waist)) * radius * 0.16)
            path.addQuadCurve(to: nextTip, control: control)
        }
        path.closeSubpath()
        return path
    }
}
