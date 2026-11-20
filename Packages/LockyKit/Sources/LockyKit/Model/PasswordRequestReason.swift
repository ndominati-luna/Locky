import Foundation

/// Why the Mac asks the iPhone for the session password.
public enum PasswordRequestReason: String, Codable, Sendable {
    /// The iPhone came back in range and automatic unlock is enabled.
    case proximity
    /// Someone clicked "Unlock with Locky" above the Mac lock screen.
    case lockScreenButton
}
