import Foundation

/// Loads private symbols lazily with `dlsym`, so a missing symbol on a future macOS degrades a
/// feature instead of preventing Locky from launching (no linking against private frameworks).
enum PrivateSymbols {
    static func load<T>(_ symbol: String, from path: String, as type: T.Type) -> T? {
        guard let handle = dlopen(path, RTLD_LAZY), let pointer = dlsym(handle, symbol) else { return nil }
        return unsafeBitCast(pointer, to: type)
    }

    static let loginFramework: String = "/System/Library/PrivateFrameworks/login.framework/Versions/A/login"
    static let skyLightFramework: String = "/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight"
    static let ioBluetoothFramework: String = "/System/Library/Frameworks/IOBluetooth.framework/IOBluetooth"
}
