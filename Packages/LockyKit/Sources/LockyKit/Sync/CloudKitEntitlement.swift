import Foundation
import MachO
import Security

/// Tells whether the running app has the iCloud (CloudKit) entitlement.
///
/// Instantiating a `CKContainer` without it raises an Objective-C exception and kills the app. It
/// happens with unsigned builds (CI, `CODE_SIGNING_ALLOWED=NO` simulator builds): Locky then simply
/// runs without iCloud synchronization.
enum CloudKitEntitlement {
    private static let key: String = "com.apple.developer.icloud-services"

    static let isPresent: Bool = {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        return SecTaskCopyValueForEntitlement(task, key as CFString, nil) != nil
        #elseif targetEnvironment(simulator)
        // Simulator builds carry their entitlements in a section of the main executable.
        guard let header = _dyld_get_image_header(0) else { return false }
        var size: UInt = 0
        let pointer: UnsafeMutablePointer<UInt8>? = header.withMemoryRebound(to: mach_header_64.self, capacity: 1) {
            getsectiondata($0, "__TEXT", "__entitlements", &size)
        }
        guard let pointer, size > 0 else { return false }
        return String(decoding: UnsafeBufferPointer(start: pointer, count: Int(size)), as: UTF8.self).contains(key)
        #else
        // Device builds are always signed with their provisioning profile.
        return true
        #endif
    }()
}
