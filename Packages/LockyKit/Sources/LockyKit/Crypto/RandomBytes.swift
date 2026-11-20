import Foundation

extension Data {
    /// Cryptographically secure random bytes.
    public static func randomBytes(count: Int) -> Data {
        var generator: SystemRandomNumberGenerator = .init()
        return Data((0..<count).map { _ in UInt8.random(in: .min ... .max, using: &generator) })
    }
}

extension UUID {
    /// The 16 raw bytes of the identifier.
    public var rawBytes: Data {
        withUnsafeBytes(of: uuid) { Data($0) }
    }
}
