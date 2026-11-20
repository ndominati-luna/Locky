import AppKit
import Foundation

/// Pre-filled support email, like the former "I need your help" menu item.
@MainActor
enum MacSupportMail {
    static func url(model: MacAppModel) -> URL {
        var body: String = "\n\n---\n"
        body += "Locky for Mac \(MacDeviceInfo.appVersion)\n"
        body += "\(MacDeviceInfo.productName) (\(MacDeviceInfo.modelIdentifier)) — macOS \(MacDeviceInfo.systemVersion)\n"
        if let device = model.preferences.device {
            body += "iPhone: \(device.modelIdentifier) — iOS \(device.systemVersion) — Locky \(device.appVersion)\n"
        }
        var components: URLComponents = .init()
        components.scheme = "mailto"
        components.path = "contact-locky@lunabee.com"
        components.queryItems = [
            .init(name: "subject", value: String(localized: "I need your help")),
            .init(name: "body", value: body)
        ]
        return components.url ?? URL(fileURLWithPath: "/")
    }
}
