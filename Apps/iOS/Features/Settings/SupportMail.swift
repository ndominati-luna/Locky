import Foundation
import LockyKit

/// Pre-filled support email (same information as the former "I need your help" email).
@MainActor
enum SupportMail {
    static let address: String = "contact-locky@lunabee.com"

    static func url(macStatus: MacStatus?) -> URL {
        var body: String = "\n\n---\n"
        body += "Locky \(LocalDevice.appVersion)\n"
        body += "iOS \(LocalDevice.systemVersion) — \(LocalDevice.modelIdentifier)\n"
        if let macStatus {
            body += "Mac: \(macStatus.productName) (\(macStatus.model)) — macOS \(macStatus.systemVersion)\n"
        }
        var components: URLComponents = .init()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            .init(name: "subject", value: String(localized: "I need your help")),
            .init(name: "body", value: body)
        ]
        return components.url ?? URL(string: "mailto:\(address)")!
    }
}
