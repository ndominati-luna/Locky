import Foundation

/// A Security framework error.
public struct KeychainError: Error, Sendable, Equatable {
    public let status: OSStatus
}
