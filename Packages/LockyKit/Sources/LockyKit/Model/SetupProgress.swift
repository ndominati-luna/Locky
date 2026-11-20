import Foundation

/// Where the user is in the setup that follows the pairing, kept in sync between the Mac and the
/// iPhone so both screens guide the user through the same first try.
public enum SetupProgress: String, Codable, Sendable, CaseIterable {
    /// The Mac lists the permissions Locky needs.
    case permissions
    /// The guided first try started: walk away with the iPhone, then come back.
    case firstTry
    /// Mac → iPhone: Locky locked the Mac, then unlocked it when the user came back.
    case succeeded
    /// The setup is over (first try done, or skipped on either device).
    case finished
}
