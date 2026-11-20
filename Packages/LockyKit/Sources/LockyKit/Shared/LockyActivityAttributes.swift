#if os(iOS)
import ActivityKit
import Foundation

/// The Locky Live Activity: distance to the Mac and its state on the Lock Screen and in the
/// Dynamic Island, with the round Locky button. Started by the iPhone app, rendered by the widget
/// extension (which reads the images of the Mac from the App Group).
public struct LockyActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable, Sendable {
        public var lockState: LockState
        public var lockStateDate: Date?
        /// `true` while the iPhone and the Mac are connected over Bluetooth.
        public var isConnected: Bool
        /// Estimated distance to the Mac in meters, `nil` when unknown.
        public var distance: Double?
        /// Distance at which the Mac locks, in meters.
        public var lockDistance: Double
        /// `false` when automatic locking is paused on the Mac.
        public var isAutoLockEnabled: Bool
        /// Locky is typing the password on the Mac.
        public var isUnlocking: Bool
        /// When `true`, only the Apple Watch may unlock the Mac.
        public var unlockOnlyFromWatch: Bool
        /// Version of the images of the Mac in the App Group: the activity is only redrawn when its
        /// state changes, so a new wallpaper has to change it.
        public var imagesVersion: String?

        public init(
            lockState: LockState,
            lockStateDate: Date?,
            isConnected: Bool,
            distance: Double?,
            lockDistance: Double,
            isAutoLockEnabled: Bool,
            isUnlocking: Bool,
            unlockOnlyFromWatch: Bool,
            imagesVersion: String? = nil
        ) {
            self.lockState = lockState
            self.lockStateDate = lockStateDate
            self.isConnected = isConnected
            self.distance = distance
            self.lockDistance = lockDistance
            self.isAutoLockEnabled = isAutoLockEnabled
            self.isUnlocking = isUnlocking
            self.unlockOnlyFromWatch = unlockOnlyFromWatch
            self.imagesVersion = imagesVersion
        }

        /// The round button can send its command.
        public var isButtonEnabled: Bool {
            isConnected && !isUnlocking && !(lockState == .locked && unlockOnlyFromWatch)
        }

        /// State used by previews.
        public static let preview: ContentState = .init(
            lockState: .unlocked,
            lockStateDate: .now.addingTimeInterval(-1_500),
            isConnected: true,
            distance: 0.6,
            lockDistance: 1.5,
            isAutoLockEnabled: true,
            isUnlocking: false,
            unlockOnlyFromWatch: false
        )
    }

    public var macName: String
    public var family: MacFamily

    public init(macName: String, family: MacFamily) {
        self.macName = macName
        self.family = family
    }
}
#endif
