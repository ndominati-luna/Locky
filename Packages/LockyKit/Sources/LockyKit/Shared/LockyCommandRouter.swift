import Foundation

/// Lets App Intents run commands directly when they are performed inside the iPhone app process,
/// and fall back to ``SharedCommandQueue`` when they run inside an extension.
@MainActor
public enum LockyCommandRouter {
    /// Installed by the iPhone app at launch. Returns `true` when the command was sent to the Mac.
    public static var handler: (@MainActor (LockyCommand, CommandOrigin) async -> Bool)?

    /// Performs or queues a command.
    @discardableResult
    public static func perform(_ command: LockyCommand, origin: CommandOrigin) async -> Bool {
        if let handler {
            return await handler(command, origin)
        }
        SharedCommandQueue.enqueue(.init(command: command, origin: origin))
        return true
    }
}
