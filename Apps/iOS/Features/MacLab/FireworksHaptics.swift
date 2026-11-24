import CoreHaptics

/// The fireworks in the hand: each rocket hisses as it rises, booms as it bursts, and its stars
/// crackle as they fall (see ``FireworksShow``).
@MainActor
final class FireworksHaptics {
    private var engine: CHHapticEngine?

    func play() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        do {
            let engine: CHHapticEngine = try .init()
            engine.playsHapticsOnly = true
            engine.isAutoShutdownEnabled = true
            try engine.start()
            let player: CHHapticPatternPlayer = try engine.makePlayer(with: .init(events: Self.events(), parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
            self.engine = engine
        } catch {
            engine = nil
        }
    }

    func stop() {
        engine?.stop()
        engine = nil
    }

    private static func events() -> [CHHapticEvent] {
        var events: [CHHapticEvent] = []
        for rocket in FireworksShow.rockets {
            var scatter: FireworksShow.Scatter = .init(seed: rocket.seed &+ 7)
            // The hiss of the rise, growing.
            let steps: Int = 3
            for step in 0..<steps {
                let share: Double = Double(step) / Double(steps)
                events.append(continuous(
                    at: rocket.launch + FireworksShow.flight * share,
                    duration: FireworksShow.flight / Double(steps),
                    intensity: Float(0.12 + 0.1 * Double(step)),
                    sharpness: Float(0.25 + 0.15 * Double(step))
                ))
            }
            // The boom, and its rumble.
            events.append(transient(at: rocket.burstTime, intensity: rocket.isBig ? 1 : 0.85, sharpness: 0.3))
            events.append(continuous(at: rocket.burstTime, duration: rocket.isBig ? 0.3 : 0.2, intensity: rocket.isBig ? 0.7 : 0.5, sharpness: 0.08))
            // The crackle of the stars.
            for _ in 0..<(rocket.isBig ? 12 : 7) {
                events.append(transient(
                    at: rocket.burstTime + scatter.next(in: 0.15...0.95),
                    intensity: Float(scatter.next(in: 0.22...0.5)),
                    sharpness: Float(scatter.next(in: 0.75...1))
                ))
            }
        }
        return events
    }

    private static func transient(at time: Double, intensity: Float, sharpness: Float) -> CHHapticEvent {
        .init(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time
        )
    }

    private static func continuous(at time: Double, duration: Double, intensity: Float, sharpness: Float) -> CHHapticEvent {
        .init(
            eventType: .hapticContinuous,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: time,
            duration: duration
        )
    }
}
