import Foundation
import LockyKit
import Observation

/// Preferences of the Mac app. iPhone driven preferences are mirrored here so they apply even
/// before the iPhone reconnects.
@MainActor
@Observable
final class MacPreferences {
    private enum Key {
        static let autoLock: String = "locky.autoLockEnabled"
        static let lockAnimation: String = "locky.lockAnimation"
        static let lockScreenOverlay: String = "locky.lockScreenOverlay"
        static let lockAnimationTitle: String = "locky.lockAnimationTitle"
        static let phonePreferences: String = "locky.phonePreferences"
        static let device: String = "locky.pairedDevice"
        static let unlockCount: String = "locky.unlockCount"
        static let setupCompleted: String = "locky.setupCompleted"
        static let lowBatteryWarned: String = "locky.lowBatteryWarned"
    }

    @ObservationIgnored private let defaults: UserDefaults = .standard

    /// "Locky activated": automatic locking when the iPhone walks away.
    var isAutoLockEnabled: Bool {
        didSet { defaults.set(isAutoLockEnabled, forKey: Key.autoLock) }
    }

    /// Animated transitions when locking and unlocking.
    var isLockAnimationEnabled: Bool {
        didSet { defaults.set(isLockAnimationEnabled, forKey: Key.lockAnimation) }
    }

    /// Text under the Locky logo in the lock animation; empty for "Locky".
    var lockAnimationTitle: String {
        didSet { defaults.set(lockAnimationTitle, forKey: Key.lockAnimationTitle) }
    }

    /// The text actually displayed under the logo.
    var effectiveLockAnimationTitle: String {
        let trimmed: String = lockAnimationTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Locky" : trimmed
    }

    /// "Unlock with Locky" panel displayed above the lock screen.
    var isLockScreenOverlayEnabled: Bool {
        didSet { defaults.set(isLockScreenOverlayEnabled, forKey: Key.lockScreenOverlay) }
    }

    /// Preferences chosen on the iPhone.
    var phonePreferences: PhonePreferences {
        didSet { defaults.set(try? JSONEncoder().encode(phonePreferences), forKey: Key.phonePreferences) }
    }

    /// Last status sent by the iPhone.
    var device: DeviceStatus? {
        didSet { defaults.set(device.flatMap { try? JSONEncoder().encode($0) }, forKey: Key.device) }
    }

    /// Number of unlocks performed by Locky.
    var unlockCount: Int {
        didSet { defaults.set(unlockCount, forKey: Key.unlockCount) }
    }

    /// The guided first try (lock by walking away, unlock by coming back) succeeded: it is
    /// mandatory after a pairing. `nil` for the pairings made before it was.
    var isSetupCompleted: Bool? {
        didSet { defaults.set(isSetupCompleted, forKey: Key.setupCompleted) }
    }

    init() {
        isAutoLockEnabled = defaults.object(forKey: Key.autoLock) as? Bool ?? true
        isLockAnimationEnabled = defaults.object(forKey: Key.lockAnimation) as? Bool ?? true
        isLockScreenOverlayEnabled = defaults.object(forKey: Key.lockScreenOverlay) as? Bool ?? true
        lockAnimationTitle = defaults.string(forKey: Key.lockAnimationTitle) ?? ""
        phonePreferences = defaults.data(forKey: Key.phonePreferences)
            .flatMap { try? JSONDecoder().decode(PhonePreferences.self, from: $0) } ?? .init()
        device = defaults.data(forKey: Key.device).flatMap { try? JSONDecoder().decode(DeviceStatus.self, from: $0) }
        unlockCount = defaults.integer(forKey: Key.unlockCount)
        isSetupCompleted = defaults.object(forKey: Key.setupCompleted) as? Bool
    }

    func resetPairingRelatedValues() {
        phonePreferences = .init()
        device = nil
        unlockCount = 0
        isAutoLockEnabled = true
    }
}
