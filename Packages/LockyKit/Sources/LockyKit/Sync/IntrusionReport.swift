import Foundation

/// A photo taken by the Mac while someone tried to use it in the owner's absence
/// (replaces the old Parse `Intrusion` class).
public struct IntrusionReport: Sendable, Identifiable, Hashable {
    /// CloudKit record name.
    public var id: String
    public var macID: UUID
    public var macName: String
    public var date: Date
    /// JPEG photo, `nil` when the camera was not available.
    public var photo: Data?

    public init(id: String, macID: UUID, macName: String, date: Date, photo: Data?) {
        self.id = id
        self.macID = macID
        self.macName = macName
        self.date = date
        self.photo = photo
    }
}
