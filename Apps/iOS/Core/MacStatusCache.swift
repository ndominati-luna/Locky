import Foundation
import LockyKit

/// Last known Mac status, displayed while the Mac is out of reach.
enum MacStatusCache {
    private static let key: String = "locky.macStatus"

    static func load() -> MacStatus? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(MacStatus.self, from: $0) }
    }

    static func save(_ status: MacStatus?) {
        UserDefaults.standard.set(status.flatMap { try? JSONEncoder().encode($0) }, forKey: key)
    }
}
