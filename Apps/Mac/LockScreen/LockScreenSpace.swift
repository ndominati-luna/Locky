import AppKit
import OSLog

/// Displays windows *above* the macOS lock screen.
///
/// Since macOS Sonoma, the lock screen lives in its own SkyLight space: the old trick of raising a
/// window to `CGShieldingWindowLevel() + 1` no longer shows anything while the session is locked.
/// Locky creates its own space at the absolute level macOS uses for notifications on the lock
/// screen and moves its overlay windows into it.
@MainActor
final class LockScreenSpace {
    static let shared: LockScreenSpace = .init()

    /// Absolute level of the space (`kSLSSpaceAbsoluteLevelNotificationCenterAtScreenLock`).
    private static let absoluteLevel: Int32 = 400

    private typealias MainConnectionID = @convention(c) () -> Int32
    private typealias SpaceCreate = @convention(c) (Int32, Int32, UnsafeRawPointer?) -> UInt64
    private typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, UInt64, Int32) -> Int32
    private typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    private typealias AddWindowsAndRemoveFromSpaces = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "LockScreenSpace")
    private let connection: Int32
    private let space: UInt64
    private let addWindows: AddWindowsAndRemoveFromSpaces?

    /// `false` when SkyLight changed and the overlay cannot be shown above the lock screen.
    let isAvailable: Bool

    private init() {
        let path: String = PrivateSymbols.skyLightFramework
        guard
            let mainConnectionID = PrivateSymbols.load("SLSMainConnectionID", from: path, as: MainConnectionID.self),
            let spaceCreate = PrivateSymbols.load("SLSSpaceCreate", from: path, as: SpaceCreate.self),
            let setLevel = PrivateSymbols.load("SLSSpaceSetAbsoluteLevel", from: path, as: SpaceSetAbsoluteLevel.self),
            let showSpaces = PrivateSymbols.load("SLSShowSpaces", from: path, as: ShowSpaces.self),
            let addWindows = PrivateSymbols.load("SLSSpaceAddWindowsAndRemoveFromSpaces", from: path, as: AddWindowsAndRemoveFromSpaces.self)
        else {
            connection = 0
            space = 0
            addWindows = nil
            isAvailable = false
            logger.error("SkyLight symbols unavailable: no overlay above the lock screen")
            return
        }
        connection = mainConnectionID()
        space = spaceCreate(connection, 1, nil)
        _ = setLevel(connection, space, Self.absoluteLevel)
        _ = showSpaces(connection, [NSNumber(value: space)] as CFArray)
        self.addWindows = addWindows
        isAvailable = space != 0
    }

    /// Moves a window into the lock screen space. The window must be ordered on screen.
    func adopt(_ window: NSWindow) {
        guard isAvailable, let addWindows else { return }
        addWindows(connection, space, [NSNumber(value: window.windowNumber)] as CFArray, 7)
    }
}
