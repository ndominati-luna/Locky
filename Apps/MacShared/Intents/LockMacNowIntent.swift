import AppIntents
import LockyKit

/// Locks this Mac now (desktop widget, Control Center, menu bar control, Shortcuts, Spotlight).
struct LockMacNowIntent: AppIntent {
    static let title: LocalizedStringResource = "Lock Mac"
    static let description: IntentDescription = .init("Locks this Mac now.")

    func perform() async throws -> some IntentResult {
        await MacCommandRouter.perform(.lockNow)
        return .result()
    }
}
