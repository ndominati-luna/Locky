import AppKit
import Foundation
import IOKit
import IOKit.ps
import LocalAuthentication
import LockyKit
import SystemConfiguration

/// Information about this Mac.
enum MacDeviceInfo {
    /// Computer name, as set in System Settings > General > Sharing.
    static var name: String {
        (SCDynamicStoreCopyComputerName(nil, nil) as String?) ?? Host.current().localizedName ?? "Mac"
    }

    /// Model identifier ("MacBookPro18,4", "Mac16,7").
    static var modelIdentifier: String {
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var buffer: [CChar] = .init(repeating: 0, count: max(size, 1))
        sysctlbyname("hw.model", &buffer, &size, nil, 0)
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// Marketing name ("MacBook Pro (14-inch, 2021)") read from the device tree, as System
    /// Information does. Works for every Apple silicon Mac, including future ones.
    static var productName: String {
        let entry: io_registry_entry_t = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        defer { IOObjectRelease(entry) }
        guard
            entry != 0,
            let value = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data
        else { return modelIdentifier }
        return String(decoding: value.prefix { $0 != 0 }, as: UTF8.self)
    }

    /// Touch ID can unlock this Mac: a sensor (built in, or on a Magic Keyboard connected now) and
    /// a finger enrolled. A Mac without it keeps the Unlock button of Locky on its lock screen.
    static var hasTouchID: Bool {
        let context: LAContext = .init()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) && context.biometryType == .touchID
    }

    static var family: MacFamily {
        let fromName: MacFamily = .init(productName: productName)
        if fromName != .unknown { return fromName }
        return hasInternalBattery ? .macBook : .unknown
    }

    static var systemVersion: String {
        let version: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }

    static var userName: String {
        NSFullUserName()
    }

    static var appVersion: String {
        let info: [String: Any] = Bundle.main.infoDictionary ?? [:]
        return "\(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))"
    }

    private static var hasInternalBattery: Bool {
        guard
            let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return false }
        return sources.contains { source in
            let description: [String: Any]? = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any]
            return description?[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
        }
    }
}
