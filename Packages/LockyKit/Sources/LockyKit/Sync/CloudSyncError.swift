import Foundation

/// Errors raised by ``CloudSync``.
public enum CloudSyncError: Error, Sendable {
    /// No iCloud account, or iCloud Drive disabled for Locky.
    case accountUnavailable
}
