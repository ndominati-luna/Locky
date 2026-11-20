import Foundation

/// Hands commands from extensions to the iPhone app through the App Group, and wakes the app up
/// with a Darwin notification.
public enum SharedCommandQueue {
    /// Darwin notification posted when a command is enqueued.
    public static let notificationName: String = "studio.lunabee.locky.command"
    private static let queueKey: String = "locky.pendingCommands"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStore.appGroupIdentifier)
    }

    /// Queues a command and notifies the app.
    public static func enqueue(_ command: PendingCommand) {
        var commands: [PendingCommand] = load()
        commands.append(command)
        store(commands)
        DarwinNotificationCenter.post(notificationName)
    }

    /// Returns and removes every pending command that has not expired.
    public static func drain(now: Date = .now) -> [PendingCommand] {
        let commands: [PendingCommand] = load()
        store([])
        return commands.filter { now.timeIntervalSince($0.date) <= PendingCommand.lifetime }
    }

    private static func load() -> [PendingCommand] {
        guard
            let data = defaults?.data(forKey: queueKey),
            let commands = try? JSONDecoder().decode([PendingCommand].self, from: data)
        else { return [] }
        return commands
    }

    private static func store(_ commands: [PendingCommand]) {
        guard let data = try? JSONEncoder().encode(commands) else { return }
        defaults?.set(data, forKey: queueKey)
    }
}
