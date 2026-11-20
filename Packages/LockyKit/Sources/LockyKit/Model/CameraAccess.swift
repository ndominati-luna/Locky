import Foundation

/// Whether Locky on the Mac may use its camera (photos of intruders).
public enum CameraAccess: String, Codable, Sendable, CaseIterable {
    /// Allowed: intruders are photographed.
    case authorized
    /// Never asked: macOS asks the next time Locky tries, on an unlocked Mac.
    case notDetermined
    /// Refused (or restricted): only System Settings can allow it again.
    case denied
    /// The Mac has no camera (Mac mini, Mac Studio without a display camera…).
    case unavailable

    /// Intruder detection can photograph intruders.
    public var canTakePhotos: Bool {
        self == .authorized
    }
}
