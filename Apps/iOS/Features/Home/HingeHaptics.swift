import CoreHaptics

/// A hinge in the hand (the lid of a MacBook, the stand of an iMac): a fine grain as it turns, which
/// gives the fingers a light continuous texture while they move, and one clean knock at its stops.
/// Core Haptics rather than the system impacts, for a knock stronger than their heaviest.
@MainActor
final class HingeHaptics {
    private let isSupported: Bool = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private var engine: CHHapticEngine?

    /// One grain of the hinge, every few degrees it turns: the faster, the closer they come.
    /// Barely there, a hint of the hinge rather than a vibration; a little crisp, so that so faint a
    /// tap still reads as a tap.
    func grain() {
        play([Self.transient(intensity: 0.18, sharpness: 0.35)])
    }

    /// A stop: a single sharp tap at full strength, with nothing held under it, which would
    /// blur it into a rumble. `isDeep` for the stop that closes (a lid shut on the keyboard), a little
    /// deeper than the one that opens.
    func knock(isDeep: Bool) {
        play([Self.transient(intensity: 1, sharpness: isDeep ? 0.6 : 0.8)])
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
