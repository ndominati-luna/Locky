import Foundation

/// App Group storage shared by the Mac app, its desktop widget and its controls.
///
/// On macOS, App Group identifiers are prefixed with the team identifier.
public enum MacSharedStore {
    /// App Group identifier of the Mac app and its widget extension.
    public static let appGroupIdentifier: String = "VH79XGK7M2.studio.lunabee.locky.mac"
    /// Darwin notification posted when a command is queued for the Mac app.
    public static let commandNotificationName: String = "VH79XGK7M2.studio.lunabee.locky.mac.command"

    private static let stateKey: String = "locky.mac.widgetState"
    private static let commandsKey: String = "locky.mac.commands"
    private static let phoneImageFileName: String = "widget-phone.png"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier)
    }

    private static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
    }

    // MARK: - State

    public static func state() -> MacWidgetState {
        guard
            let data = defaults?.data(forKey: stateKey),
            let state = try? JSONDecoder().decode(MacWidgetState.self, from: data)
        else { return .unpaired }
        return state
    }

    public static func save(_ state: MacWidgetState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults?.set(data, forKey: stateKey)
    }

    /// Product image of the paired iPhone (PNG).
    public static var phoneImage: Data? {
        get { containerURL.flatMap { try? Data(contentsOf: $0.appending(path: phoneImageFileName)) } }
        set {
            guard let url = containerURL?.appending(path: phoneImageFileName) else { return }
            if let newValue {
                try? newValue.write(to: url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    // MARK: - Commands

    /// Queues a command for the Mac app and wakes it up.
    public static func enqueue(_ command: MacCommand) {
        var commands: [MacCommand] = pendingCommands()
        commands.append(command)
        defaults?.set(try? JSONEncoder().encode(commands), forKey: commandsKey)
        DarwinNotificationCenter.post(commandNotificationName)
    }

    /// Returns and removes the queued commands.
    public static func drainCommands() -> [MacCommand] {
        let commands: [MacCommand] = pendingCommands()
        defaults?.removeObject(forKey: commandsKey)
        return commands
    }

    private static func pendingCommands() -> [MacCommand] {
        guard
            let data = defaults?.data(forKey: commandsKey),
            let commands = try? JSONDecoder().decode([MacCommand].self, from: data)
        else { return [] }
        return commands
    }
}

/// Lets Mac App Intents act directly when they run inside the Mac app, and queue the command for it
/// when they run inside the widget extension.
@MainActor
public enum MacCommandRouter {
    /// Installed by the Mac app at launch.
    public static var handler: (@MainActor (MacCommand) -> Void)?

    public static func perform(_ command: MacCommand) {
        if let handler {
            handler(command)
        } else {
            MacSharedStore.enqueue(command)
        }
    }
}
