import AVFoundation
import CoreMotion
import CoreTelephony
import Foundation
import LockyKit
import OSLog

/// What the iPhone listens to during a measurement of the waves (``WaveScan/captureDuration``),
/// while Locky is on screen:
/// - Bluetooth Low Energy, the whole time;
/// - the sound, with the microphone (other apps keep playing);
/// - the magnetic field, ten times a second;
/// - the generation of the mobile network.
@MainActor
final class PhoneWaveCapturer {
    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "Waves")
    private let neighbors: BluetoothNeighborScanner = .init()
    private let motion: CMMotionManager = .init()
    private var engine: AVAudioEngine?
    private var analyzer: SoundAnalyzer?
    private var fieldSamples: [Double] = []
    private var isFieldCalibrated: Bool = true

    /// Asks for the microphone before the first measurement (iOS shows its alert once).
    func prepare() async {
        if AVAudioApplication.shared.recordPermission == .undetermined {
            _ = await AVAudioApplication.requestRecordPermission()
        }
    }

    func capture(_ run: WaveScanRun) async -> PhoneWaveCapture {
        neighbors.start()
        startMagneticField()
        await prepare()
        let isListening: Bool = startSound()
        let remaining: TimeInterval = run.endsAt.timeIntervalSinceNow
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
        let sound: SoundSpectrum? = isListening ? stopSound() : nil
        let field: MagneticField? = stopMagneticField()
        return .init(
            bluetoothDevices: neighbors.stop(),
            sound: sound,
            magneticField: field,
            cellular: Self.cellular()
        )
    }

    // MARK: - Sound

    private func startSound() -> Bool {
        guard AVAudioApplication.shared.recordPermission == .granted else { return false }
        let session: AVAudioSession = .sharedInstance()
        do {
            // Measurement mode: no automatic gain, no noise reduction. Other apps keep playing.
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
            try session.setActive(true)
            let engine: AVAudioEngine = .init()
            let format: AVAudioFormat = engine.inputNode.outputFormat(forBus: 0)
            guard format.sampleRate > 0 else { return false }
            let analyzer: SoundAnalyzer = .init(sampleRate: format.sampleRate)
            engine.inputNode.installTap(
                onBus: 0,
                bufferSize: AVAudioFrameCount(SoundAnalyzer.windowSize),
                format: format,
                block: Self.tap { [weak self] samples in
                    Task { @MainActor in self?.analyzer?.add(samples) }
                }
            )
            try engine.start()
            self.engine = engine
            self.analyzer = analyzer
            return true
        } catch {
            logger.error("Microphone not started: \(error.localizedDescription, privacy: .public)")
            restoreAudioSession()
            return false
        }
    }

    private func stopSound() -> SoundSpectrum? {
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        let spectrum: SoundSpectrum? = analyzer?.spectrum()
        analyzer = nil
        restoreAudioSession()
        return spectrum
    }

    private func restoreAudioSession() {
        let session: AVAudioSession = .sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        // The sounds of Locky play along with other apps, as before.
        try? session.setCategory(.ambient)
    }

    /// Built outside the main actor: the audio thread calls it.
    nonisolated private static func tap(_ handler: @escaping @Sendable ([Float]) -> Void) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard let channel = buffer.floatChannelData?[0] else { return }
            handler(Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
        }
    }

    // MARK: - Magnetic field

    private func startMagneticField() {
        fieldSamples = []
        isFieldCalibrated = true
        if CMMotionManager.availableAttitudeReferenceFrames().contains(.xArbitraryCorrectedZVertical), motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 0.1
            motion.startDeviceMotionUpdates(using: .xArbitraryCorrectedZVertical, to: .main) { [weak self] data, _ in
                guard let data else { return }
                let field: CMCalibratedMagneticField = data.magneticField
                let strength: Double = (field.field.x * field.field.x + field.field.y * field.field.y + field.field.z * field.field.z).squareRoot()
                MainActor.assumeIsolated {
                    guard let self else { return }
                    // Until iOS has calibrated it, the field reads 0.
                    guard field.accuracy != .uncalibrated, strength > 0 else { return }
                    self.fieldSamples.append(strength)
                }
            }
        } else if motion.isMagnetometerAvailable {
            isFieldCalibrated = false
            motion.magnetometerUpdateInterval = 0.1
            motion.startMagnetometerUpdates(to: .main) { [weak self] data, _ in
                guard let data else { return }
                let field: CMMagneticField = data.magneticField
                let strength: Double = (field.x * field.x + field.y * field.y + field.z * field.z).squareRoot()
                MainActor.assumeIsolated { self?.fieldSamples.append(strength) }
            }
        }
    }

    private func stopMagneticField() -> MagneticField? {
        if motion.isDeviceMotionActive {
            motion.stopDeviceMotionUpdates()
        }
        if motion.isMagnetometerActive {
            motion.stopMagnetometerUpdates()
        }
        guard !fieldSamples.isEmpty else { return nil }
        // At most 200 readings: plenty for the chart.
        let step: Int = max(1, fieldSamples.count / 200)
        let samples: [Double] = stride(from: 0, to: fieldSamples.count, by: step).map { fieldSamples[$0] }
        return .init(samples: samples, isCalibrated: isFieldCalibrated)
    }

    // MARK: - Mobile network

    private static func cellular() -> CellularTechnology? {
        let technologies: [CellularTechnology] = (CTTelephonyNetworkInfo().serviceCurrentRadioAccessTechnology ?? [:]).values
            .compactMap(CellularTechnology.init(radioAccessTechnology:))
        let order: [CellularTechnology] = [.fiveG, .fourG, .threeG, .twoG]
        return order.first(where: technologies.contains)
    }
}
