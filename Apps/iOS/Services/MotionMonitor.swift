import CoreMotion
import Foundation
import LockyKit
import OSLog

/// Tells whether the iPhone is moving.
///
/// Two complementary sources:
/// - live device motion (5 Hz), compared to the baseline measured during the pairing, reacts within
///   a fraction of a second while the app runs;
/// - the pedometer, queried retrospectively each time the app wakes up for a Bluetooth event: it
///   still knows the user walked away even if iOS suspended the app in between.
@MainActor
final class MotionMonitor {
    /// Called when the moving state changes.
    var onChange: ((Bool) -> Void)?

    private(set) var isMoving: Bool = false
    var baseline: MotionBaseline = .zero

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "Motion")
    private let motionManager: CMMotionManager = .init()
    private let pedometer: CMPedometer = .init()
    private var lastMovement: ContinuousClock.Instant?
    private var stillnessTask: Task<Void, Never>?
    private var isRunning: Bool = false

    /// Starts live monitoring.
    func start() {
        guard !isRunning, motionManager.isDeviceMotionAvailable else { return }
        isRunning = true
        motionManager.deviceMotionUpdateInterval = 0.2
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let sample: MotionSample = .init(
                acceleration: [motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z],
                rotation: [motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z]
            )
            MainActor.assumeIsolated {
                guard let self, self.baseline.isMovement(sample) else { return }
                self.movementDetected()
            }
        }
    }

    /// Stops live monitoring.
    func stop() {
        isRunning = false
        motionManager.stopDeviceMotionUpdates()
        stillnessTask?.cancel()
        setMoving(false)
    }

    /// Checks the pedometer for steps during the last seconds (works after a suspension).
    func refreshFromPedometer() {
        guard CMPedometer.isStepCountingAvailable(), CMPedometer.authorizationStatus() != .denied else { return }
        let end: Date = .now
        // Sendable: CoreMotion calls back on its own queue. Without it the closure would inherit the
        // main actor isolation, and Swift traps as soon as it runs elsewhere.
        pedometer.queryPedometerData(from: end.addingTimeInterval(-4), to: end) { @Sendable [weak self] data, _ in
            let steps: Int = data?.numberOfSteps.intValue ?? 0
            guard steps >= 2 else { return }
            Task { @MainActor in self?.movementDetected() }
        }
    }

    /// Measures the sensors noise while the iPhone lies still.
    func calibrate() async -> MotionBaseline {
        guard motionManager.isDeviceMotionAvailable else { return .zero }
        let collector: SampleCollector = .init()
        let calibrationManager: CMMotionManager = .init()
        calibrationManager.deviceMotionUpdateInterval = 0.05
        calibrationManager.startDeviceMotionUpdates(to: .main) { motion, _ in
            guard let motion else { return }
            let sample: MotionSample = .init(
                acceleration: [motion.userAcceleration.x, motion.userAcceleration.y, motion.userAcceleration.z],
                rotation: [motion.rotationRate.x, motion.rotationRate.y, motion.rotationRate.z]
            )
            MainActor.assumeIsolated { collector.samples.append(sample) }
        }
        try? await Task.sleep(for: MotionBaseline.calibrationDuration)
        calibrationManager.stopDeviceMotionUpdates()
        let baseline: MotionBaseline = .measure(collector.samples)
        logger.info("Motion baseline measured from \(collector.samples.count) samples")
        return baseline
    }

    private func movementDetected() {
        lastMovement = .now
        setMoving(true)
        stillnessTask?.cancel()
        stillnessTask = Task { [weak self] in
            try? await Task.sleep(for: MotionBaseline.stillnessDelay)
            guard !Task.isCancelled else { return }
            self?.setMoving(false)
        }
    }

    private func setMoving(_ moving: Bool) {
        guard moving != isMoving else { return }
        isMoving = moving
        onChange?(moving)
    }
}

@MainActor
private final class SampleCollector {
    var samples: [MotionSample] = []
}
