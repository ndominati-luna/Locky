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
        deviceType: String? = nil
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
    }
}
