import Foundation

/// Where a lock or unlock command was triggered on the iPhone side.
public enum CommandOrigin: String, Codable, Sendable {
    /// The iPhone app itself.
    case app
    /// A Home Screen or Lock Screen widget.
    case widget
    /// A Control Center control.
    case control
    /// The Apple Watch app or one of its complications.
    case watch
    /// A notification action.
    case notification
    /// Siri, Shortcuts or Spotlight.
    case shortcut
    /// Automatic proximity based action.
    case proximity
    /// The "Unlock with Locky" button displayed above the Mac lock screen.
    case lockScreen
}
