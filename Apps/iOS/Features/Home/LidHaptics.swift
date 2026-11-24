import CoreHaptics

/// The lid of the MacBook in the hand: a fine grain as it turns on its hinge, which gives the
/// fingers a light continuous texture while they move, and a firm knock when it comes to a stop.
/// Core Haptics rather than the system impacts, for a knock stronger than their heaviest.
@MainActor
final class LidHaptics {
    private let isSupported: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    /// One grain of the hinge, every few degrees the lid turns: the faster, the closer they come.
    func grain() {
        play([Self.transient(intensity: 0.3, sharpness: 0.15)])
    }

    /// The lid stops: shut on the keyboard, a deep thud; opened as far as it goes, a drier one.
    func knock(isShut: Bool) {
        play([
            Self.transient(intensity: 1, sharpness: isShut ? 0.4 : 0.65),
            // A short body under the click, which makes it land.
            .init(
                eventType: .hapticContinuous,
                parameters: [
                    .init(parameterID: .hapticIntensity, value: isShut ? 1 : 0.75),
                    .init(parameterID: .hapticSharpness, value: 0.1)
                ],
                relativeTime: 0,
                duration: isShut ? 0.14 : 0.08
            )
        ])
    }

    private func play(_ events: [CHHapticEvent]) {
        guard isSupported else { return }
        do {
            let player: CHHapticPatternPlayer = try startedEngine().makePlayer(with: .init(events: events, parameters: []))
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            // Started again on the next one.
            engine = nil
        }
    }

    private func startedEngine() throws -> CHHapticEngine {
        if let engine {
            return engine
        }
        let engine: CHHapticEngine = try .init()
        engine.playsHapticsOnly = true
        engine.isAutoShutdownEnabled = true
        // Stopped by the system (app in the background, idle) or reset: a new one next time.
        engine.stoppedHandler = { [weak self] _ in
            Task { @MainActor in self?.engine = nil }
        }
        engine.resetHandler = { [weak self] in
            Task { @MainActor in self?.engine = nil }
        }
        try engine.start()
        self.engine = engine
        return engine
    }

    private static func transient(intensity: Float, sharpness: Float) -> CHHapticEvent {
        .init(
            eventType: .hapticTransient,
            parameters: [
                .init(parameterID: .hapticIntensity, value: intensity),
                .init(parameterID: .hapticSharpness, value: sharpness)
            ],
            relativeTime: 0
        )
    }
}
