import Foundation
import LocalAuthentication

/// Face ID / passcode check before sensitive actions.
enum BiometricGate {
    /// Asks the user to authenticate. Returns `true` on success.
    static func authenticate(reason: String) async -> Bool {
        let context: LAContext = .init()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No passcode on the device: nothing more to check.
            return true
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
        } catch {
            return false
        }
    }

    /// Name of the available biometry, for labels.
    static var biometryName: String {
        let context: LAContext = .init()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return switch context.biometryType {
        case .faceID: "Face ID"
        case .touchID: "Touch ID"
        case .opticID: "Optic ID"
        default: String(localized: "Passcode")
        }
    }
}
