import AppIntents
import LockyKit

/// Unlocks the paired Mac. The iPhone must be unlocked (Face ID / passcode) to run it.
struct UnlockMacIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Unlock Mac"
    static let description: IntentDescription = .init("Unlocks the Mac paired with Locky.")
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    func perform() async throws -> some IntentResult {
        await LockyCommandRouter.perform(.unlock, origin: .widget)
        return .result()
    }
}
