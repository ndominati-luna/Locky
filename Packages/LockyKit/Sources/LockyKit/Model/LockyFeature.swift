import Foundation

/// What a peer can do beyond the messages of the first versions. Each side announces its features
/// (``DeviceStatus/features``, ``MacStatus/features``) and sends the matching messages only to a
/// peer that announced them: an older one could not decode them.
public enum LockyFeature: String, Sendable, CaseIterable {
    /// ``LockyMessage/lockAnimation(_:)`` and ``LockyMessage/previewLockAnimation``.
    case lockAnimation
    /// ``LockyMessage/checkForUpdates``, and the version of Locky in ``MacStatus``.
    case macUpdates
    /// ``LockyMessage/autoLock(isEnabled:)`` from the iPhone.
    case autoLockFromPhone
    /// The settings of the Mac changed on the iPhone out of reach: through iCloud, then
    /// ``LockyMessage/macSettings(_:)`` (see ``MacSettingsEnvelope``).
    case cloudSettings
    /// ``LockyMessage/proximityInterest(_:)`` from the iPhone: the Mac sends the distance only as
    /// often as the iPhone shows it, instead of twice a second whatever it does.
    case proximityOnDemand

    /// What this version announces.
    public static var current: [String] {
        allCases.map(\.rawValue)
    }
}

extension DeviceStatus {
    public func supports(_ feature: LockyFeature) -> Bool {
        features?.contains(feature.rawValue) == true
    }
}

extension MacStatus {
    public func supports(_ feature: LockyFeature) -> Bool {
        features?.contains(feature.rawValue) == true
    }
}
