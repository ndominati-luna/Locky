import AppIntents
import LockyKit

/// Turns automatic locking ("Locky activated") on or off.
struct SetLockyActivatedIntent: SetValueIntent {
    static let title: LocalizedStringResource = "Locky Activated"
    static let description: IntentDescription = .init("Turns automatic locking on or off.")

    @Parameter(title: "Activated")
    var value: Bool

    func perform() async throws -> some IntentResult {
        await MacCommandRouter.perform(value ? .enableAutoLock : .disableAutoLock)
        return .result()
    }
}
