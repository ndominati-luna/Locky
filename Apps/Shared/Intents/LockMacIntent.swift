import AppIntents
import LockyKit

/// Locks the paired Mac.
///
/// Conforming to `LiveActivityIntent` makes the system run `perform()` inside the iPhone app
/// process, which owns the Bluetooth connection. When it nevertheless runs in an extension,
/// ``LockyCommandRouter`` queues the command for the app.
struct LockMacIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Lock Mac"
    static let description: IntentDescription = .init("Locks the computer paired with Locky.")

    func perform() async throws -> some IntentResult {
        await LockyCommandRouter.perform(.lock, origin: .widget)
        return .result()
    }
}
