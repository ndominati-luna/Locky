import Foundation

/// Memory pressure of the Mac, as in Activity Monitor.
public enum MemoryPressure: String, Codable, Sendable {
    case normal
    case warning
    case critical
}
