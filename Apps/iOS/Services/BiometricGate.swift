import Foundation
import LocalAuthentication

/// Face ID, Touch ID or passcode check before sensitive actions.
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

    /// Biometry of the device (Touch ID on an iPhone Duo, Face ID on the others), for labels and
    /// icons; `nil` without any (the passcode only).
    static var biometry: Biometry? {
        let context: LAContext = .init()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return switch context.biometryType {
        case .faceID: .init(name: "Face ID", symbol: "faceid")
        case .touchID: .init(name: "Touch ID", symbol: "touchid")
        case .opticID: .init(name: "Optic ID", symbol: "opticid")
        default: nil
        }
    }

    /// Name of the available biometry, or "Passcode", for labels.
    static var biometryName: String {
        biometry?.name ?? String(localized: "Passcode")
    }

    /// Symbol of the available biometry, or a padlock for the passcode.
    static var biometrySymbol: String {
        biometry?.symbol ?? "lock.fill"
    }

    struct Biometry {
        let name: String
        let symbol: String
    }
}
