import AppIntents
import LockyKit

/// Control Center toggle: on = Mac locked.
struct SetMacLockedIntent: SetValueIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Lock or Unlock Mac"
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Locked")
    var value: Bool

    func perform() async throws -> some IntentResult {
        await LockyCommandRouter.perform(value ? .lock : .unlock, origin: .control)
        return .result()
    }
}
