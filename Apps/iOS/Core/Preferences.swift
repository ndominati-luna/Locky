import Foundation
import LockyKit
import Observation

/// User preferences of the iPhone app, persisted in user defaults.
@MainActor
@Observable
final class Preferences {
    private enum Key {
        static let onboardingCompleted: String = "locky.onboardingCompleted"
        static let unlockAutomatically: String = "locky.unlockAutomatically"
        static let requireBiometrics: String = "locky.requireBiometrics"
        static let notificationsEnabled: String = "locky.notificationsEnabled"
        static let intrusionDetection: String = "locky.intrusionDetection"
        static let unlockOnlyFromWatch: String = "locky.unlockOnlyFromWatch"
        static let soundTheme: String = "locky.soundTheme"
        static let lockDistance: String = "locky.lockDistance"
        static let calibrationDistanceMigrated: String = "locky.calibrationDistanceMigrated"
        static let motionBaseline: String = "locky.motionBaseline"
        static let macImagesVersion: String = "locky.macImagesVersion"
        static let liveActivityEnabled: String = "locky.liveActivityEnabled"
        static let macSettings: String = "locky.macSettings"
        static let macSettingsUploadPending: String = "locky.macSettingsUploadPending"
        static let macLockAnimation: String = "locky.macLockAnimation"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var onboardingCompleted: Bool {
        didSet { defaults.set(onboardingCompleted, forKey: Key.onboardingCompleted) }
    }

    /// Unlock the Mac as soon as the iPhone comes back.
    var unlockAutomatically: Bool {
        didSet { defaults.set(unlockAutomatically, forKey: Key.unlockAutomatically) }
    }

    /// Ask for Face ID or Touch ID (or the passcode) before unlocking from the iPhone.
    var requireBiometrics: Bool {
        didSet { defaults.set(requireBiometrics, forKey: Key.requireBiometrics) }
    }

    /// Notify when the Mac locks or unlocks.
    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notificationsEnabled) }
    }

    /// Ask the Mac to photograph intruders.
    var intrusionDetection: Bool {
        didSet { defaults.set(intrusionDetection, forKey: Key.intrusionDetection) }
    }

    /// Only the Apple Watch may unlock the Mac.
    var unlockOnlyFromWatch: Bool {
        didSet { defaults.set(unlockOnlyFromWatch, forKey: Key.unlockOnlyFromWatch) }
    }

    /// Sound played when the Mac locks.
    var soundTheme: SoundTheme {
        didSet { defaults.set(soundTheme.rawValue, forKey: Key.soundTheme) }
    }

    /// Lock distance in meters.
    var lockDistance: Double {
        didSet { defaults.set(lockDistance, forKey: Key.lockDistance) }
    }

    /// Motion sensors noise measured during the pairing.
    /// Distance and state of the Mac on the Lock Screen and in the Dynamic Island.
    var liveActivityEnabled: Bool {
        didSet { defaults.set(liveActivityEnabled, forKey: Key.liveActivityEnabled) }
    }

    var motionBaseline: MotionBaseline {
        didSet { defaults.set(try? JSONEncoder().encode(motionBaseline), forKey: Key.motionBaseline) }
    }

    /// Version of the Mac images already received.
    var macImagesVersion: String? {
        didSet { defaults.set(macImagesVersion, forKey: Key.macImagesVersion) }
    }

    /// The settings of the Mac as last chosen here, each with its date: left in iCloud when the Mac
    /// is out of reach, sent again when it comes back (see ``MacSettingsEnvelope``).
    @ObservationIgnored var macSettings: MacSettingsEnvelope {
        didSet { defaults.set(try? JSONEncoder().encode(macSettings), forKey: Key.macSettings) }
    }

    /// ``macSettings`` changed out of reach and not in iCloud yet.
    @ObservationIgnored var isMacSettingsUploadPending: Bool {
        didSet { defaults.set(isMacSettingsUploadPending, forKey: Key.macSettingsUploadPending) }
    }

    /// The lock animation of the Mac as it last told it, shown while it is out of reach.
    @ObservationIgnored var macLockAnimation: LockAnimationSettings? {
        didSet { defaults.set(macLockAnimation.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.macLockAnimation) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingCompleted = defaults.bool(forKey: Key.onboardingCompleted)
        unlockAutomatically = defaults.object(forKey: Key.unlockAutomatically) as? Bool ?? true
        requireBiometrics = defaults.bool(forKey: Key.requireBiometrics)
        notificationsEnabled = defaults.object(forKey: Key.notificationsEnabled) as? Bool ?? true
        intrusionDetection = defaults.bool(forKey: Key.intrusionDetection)
        unlockOnlyFromWatch = defaults.bool(forKey: Key.unlockOnlyFromWatch)
        soundTheme = defaults.string(forKey: Key.soundTheme).flatMap(SoundTheme.init(rawValue:)) ?? .standard
        var storedLockDistance: Double = defaults.object(forKey: Key.lockDistance) as? Double ?? DistanceModel.defaultLockDistance
        // The calibration distance went from 20 to 10 cm: every distance reads half as far, the
        // lock distance follows so that the iPhone locks at the same place.
        if defaults.object(forKey: Key.lockDistance) != nil, !defaults.bool(forKey: Key.calibrationDistanceMigrated) {
            storedLockDistance = max(DistanceModel.lockDistanceRange.lowerBound, storedLockDistance / 2)
            defaults.set(storedLockDistance, forKey: Key.lockDistance)
        }
        defaults.set(true, forKey: Key.calibrationDistanceMigrated)
        lockDistance = storedLockDistance
        liveActivityEnabled = defaults.object(forKey: Key.liveActivityEnabled) as? Bool ?? true
        motionBaseline = defaults.data(forKey: Key.motionBaseline)
            .flatMap { try? JSONDecoder().decode(MotionBaseline.self, from: $0) } ?? .zero
        macImagesVersion = defaults.string(forKey: Key.macImagesVersion)
        macSettings = defaults.data(forKey: Key.macSettings)
            .flatMap { try? JSONDecoder().decode(MacSettingsEnvelope.self, from: $0) } ?? .init()
        isMacSettingsUploadPending = defaults.bool(forKey: Key.macSettingsUploadPending)
        macLockAnimation = defaults.data(forKey: Key.macLockAnimation)
            .flatMap { try? JSONDecoder().decode(LockAnimationSettings.self, from: $0) }
    }

    /// Preferences the Mac needs to know.
    var phonePreferences: PhonePreferences {
        .init(
            unlockAutomatically: unlockAutomatically,
            intrusionDetection: intrusionDetection,
            unlockOnlyFromWatch: unlockOnlyFromWatch,
            lockDistance: lockDistance
        )
    }

    /// Restores the pairing related defaults (used when unpairing).
    func resetPairingRelatedValues() {
        requireBiometrics = false
        unlockOnlyFromWatch = false
        lockDistance = DistanceModel.defaultLockDistance
        motionBaseline = .zero
        macImagesVersion = nil
        macSettings = .init()
        isMacSettingsUploadPending = false
        macLockAnimation = nil
    }
}
