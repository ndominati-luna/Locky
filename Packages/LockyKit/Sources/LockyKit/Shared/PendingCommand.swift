import Foundation

/// A command queued by an extension, waiting for the iPhone app to execute it.
public struct PendingCommand: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var command: LockyCommand
    public var origin: CommandOrigin
    public var date: Date

    public init(id: UUID = .init(), command: LockyCommand, origin: CommandOrigin, date: Date = .now) {
        self.id = id
        self.command = command
        self.origin = origin
        self.date = date
    }

    /// Commands older than this are dropped: locking a Mac minutes after the tap would surprise.
    public static let lifetime: TimeInterval = 30
}
