import Foundation

/// Information the Mac sends to the iPhone (over Bluetooth and CloudKit).
public struct MacStatus: Codable, Sendable, Equatable {
    public var macID: UUID
    public var name: String
    /// Model identifier, e.g. "Mac16,7".
    public var model: String
    /// Exact type of the Mac for macOS (model and color), e.g.
    /// "com.apple.macbookpro-14-2021-space-gray": picks its image in ``MacCatalog``.
    public var deviceType: String?
    /// Marketing name, e.g. "MacBook Pro (16-inch, 2024)".
    public var productName: String
    public var family: MacFamily
    public var systemVersion: String
    public var userName: String
    public var lockState: LockState
    public var lockStateDate: Date
    /// `false` when the user paused automatic locking from the Mac menu bar.
    public var isAutoLockEnabled: Bool
    public var unlockCount: Int
    /// Camera of the Mac for intruder detection, `nil` when not reported yet.
    public var cameraAccess: CameraAccess?
    /// Version of Locky for Mac, e.g. "1.0.2"; `nil` before Locky 1.0.2 for Mac.
    public var appVersion: String?
    /// Build of Locky for Mac, the version Sparkle compares; `nil` before Locky 1.0.2 for Mac.
    public var appBuild: Int?
    /// See ``LockyFeature``; `nil` before Locky 1.0.2 for Mac. Sent over Bluetooth only.
    public var features: [String]?
    /// Touch ID is set up on the Mac (a finger enrolled, built in or on a Magic Keyboard): a new
    /// pairing leaves automatic unlocking off and the Unlock button hidden. `nil` before Locky
    /// 1.0.15 for Mac. Sent over Bluetooth only.
    public var hasTouchID: Bool?
    /// The Unlock button shows on the lock screen of the Mac (``LockyFeature/unlockButton``). `nil`
    /// before Locky 1.0.15 for Mac. Sent over Bluetooth only.
    public var showsUnlockButton: Bool?

    public init(
        macID: UUID,
        name: String,
        model: String,
        productName: String,
        family: MacFamily,
        systemVersion: String,
        userName: String,
        lockState: LockState,
        lockStateDate: Date,
        isAutoLockEnabled: Bool,
        unlockCount: Int,
        cameraAccess: CameraAccess? = nil,
        deviceType: String? = nil,
        appVersion: String? = nil,
        appBuild: Int? = nil,
        features: [String]? = nil,
        hasTouchID: Bool? = nil,
        showsUnlockButton: Bool? = nil
    ) {
        self.macID = macID
        self.name = name
        self.model = model
        self.productName = productName
        self.family = family
        self.systemVersion = systemVersion
        self.userName = userName
        self.lockState = lockState
        self.lockStateDate = lockStateDate
        self.isAutoLockEnabled = isAutoLockEnabled
        self.unlockCount = unlockCount
        self.cameraAccess = cameraAccess
        self.deviceType = deviceType
        self.appVersion = appVersion
        self.appBuild = appBuild
        self.features = features
        self.hasTouchID = hasTouchID
        self.showsUnlockButton = showsUnlockButton
    }
}
