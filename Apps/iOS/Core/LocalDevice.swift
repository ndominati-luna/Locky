import Foundation
import UIKit

/// Information about this iPhone.
enum LocalDevice {
    /// Hardware identifier ("iPhone18,1").
    static var modelIdentifier: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var systemInfo: utsname = .init()
        uname(&systemInfo)
        return withUnsafeBytes(of: systemInfo.machine) { buffer in
            String(decoding: buffer.prefix { $0 != 0 }, as: UTF8.self)
        }
    }

    /// SF Symbol matching the generation of this iPhone (home button, notch or Dynamic Island), used
    /// until the Mac sends the exact product image.
    static var symbolName: String {
        let identifier: String = modelIdentifier
        let homeButtonModels: Set<String> = ["iPhone8,4", "iPhone12,8", "iPhone14,6"]
        let notchModels: Set<String> = ["iPhone17,5"]
        guard
            identifier.hasPrefix("iPhone"),
            let major = Int(identifier.dropFirst("iPhone".count).prefix { $0.isNumber })
        else { return "iphone" }
        if homeButtonModels.contains(identifier) || (major <= 10 && !["iPhone10,3", "iPhone10,6"].contains(identifier)) {
            return "iphone.gen1"
        }
        if notchModels.contains(identifier) || major < 15 {
            return "iphone.gen2"
        }
        return "iphone.gen3"
    }

    /// Name of the device (generic since iOS 16 unless the user granted the entitlement).
    @MainActor
    static var name: String {
        UIDevice.current.name
    }

    @MainActor
    static var model: String {
        UIDevice.current.model
    }

    @MainActor
    static var systemVersion: String {
        UIDevice.current.systemVersion
    }

    static var appVersion: String {
        let info: [String: Any] = Bundle.main.infoDictionary ?? [:]
        let version: String = info["CFBundleShortVersionString"] as? String ?? "?"
        let build: String = info["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
