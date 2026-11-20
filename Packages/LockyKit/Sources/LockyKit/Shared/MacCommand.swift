import Foundation

/// A command the Mac widget or controls ask the Mac app to perform.
public enum MacCommand: String, Codable, Sendable {
    case lockNow
    case enableAutoLock
    case disableAutoLock
}
