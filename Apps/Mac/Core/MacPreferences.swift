import Foundation
import LockyKit
import Observation
import SwiftUI

/// Preferences of the Mac app. iPhone driven preferences are mirrored here so they apply even
/// before the iPhone reconnects.
@MainActor
@Observable
final class MacPreferences {
    private enum Key {
        static let autoLock: String = "locky.autoLockEnabled"
        /// Before the styles: `false` when the animations were turned off.
        static let lockAnimation: String = "locky.lockAnimation"
        static let lockAnimationStyle: String = "locky.lockAnimationStyle"
        static let lockTitleStyle: String = "locky.lockTitleStyle"
        static let lockBackgroundKind: String = "locky.lockBackgroundKind"
        static let lockBackgroundColor: String = "locky.lockBackgroundColor"
        static let lockBackgroundImageVersion: String = "locky.lockBackgroundImageVersion"
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

    /// Transition when locking and unlocking; ``LockAnimationStyle/none`` locks at once.
    var lockAnimationStyle: LockAnimationStyle {
        didSet { defaults.set(lockAnimationStyle.rawValue, forKey: Key.lockAnimationStyle) }
    }

    /// How the text under the logo appears.
    var lockTitleStyle: LockTitleStyle {
        didSet { defaults.set(lockTitleStyle.rawValue, forKey: Key.lockTitleStyle) }
    }

    /// Behind the logo of the animation.
    var lockBackgroundKind: LockBackgroundKind {
        didSet { defaults.set(lockBackgroundKind.rawValue, forKey: Key.lockBackgroundKind) }
    }

    /// Color behind the logo, `RRGGBB`.
    var lockBackgroundColor: String {
        didSet { defaults.set(lockBackgroundColor, forKey: Key.lockBackgroundColor) }
    }

    /// Raised each time an image is chosen for the background (see ``LockBackgroundImage``).
    var lockBackgroundImageVersion: Int {
        didSet { defaults.set(lockBackgroundImageVersion, forKey: Key.lockBackgroundImageVersion) }
    }

    /// Everything the animations need.
    var lockAnimation: LockAnimation {
        .init(
            style: lockAnimationStyle,
            title: effectiveLockAnimationTitle,
            titleStyle: lockTitleStyle,
            background: .init(kind: lockBackgroundKind, colorHex: lockBackgroundColor, imageVersion: lockBackgroundImageVersion)
        )
    }

    /// The animation as the iPhone sees and changes it.
    var lockAnimationSettings: LockAnimationSettings {
        .init(
            style: lockAnimationStyle,
            title: lockAnimationTitle,
            titleStyle: lockTitleStyle,
            backgroundKind: lockBackgroundKind,
            backgroundColor: lockBackgroundColor,
            hasBackgroundImage: LockBackgroundImage.image(version: lockBackgroundImageVersion) != nil
        )
    }

    /// Chosen on the iPhone. The image cannot be: without one on the Mac, the background stays as it
    /// was.
    func apply(_ settings: LockAnimationSettings) {
        lockAnimationStyle = settings.style
        lockAnimationTitle = String(settings.title.prefix(LockAnimationSettings.maximumTitleLength))
        lockTitleStyle = settings.titleStyle
        if settings.backgroundKind != .image || LockBackgroundImage.image(version: lockBackgroundImageVersion) != nil {
            lockBackgroundKind = settings.backgroundKind
        }
        if settings.backgroundColor.count == 6, UInt64(settings.backgroundColor, radix: 16) != nil {
            lockBackgroundColor = settings.backgroundColor.uppercased()
        }
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
        let wasAnimationOff: Bool = defaults.object(forKey: Key.lockAnimation) as? Bool == false
        lockAnimationStyle = defaults.string(forKey: Key.lockAnimationStyle).flatMap(LockAnimationStyle.init) ?? (wasAnimationOff ? .none : .iris)
        lockTitleStyle = defaults.string(forKey: Key.lockTitleStyle).flatMap(LockTitleStyle.init) ?? .reveal
        lockBackgroundKind = defaults.string(forKey: Key.lockBackgroundKind).flatMap(LockBackgroundKind.init) ?? .color
        lockBackgroundColor = defaults.string(forKey: Key.lockBackgroundColor) ?? "000000"
        lockBackgroundImageVersion = defaults.integer(forKey: Key.lockBackgroundImageVersion)
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
