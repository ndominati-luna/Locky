import Foundation

/// Bluetooth Low Energy constants shared by the iPhone (peripheral) and the Mac (central).
///
/// The iPhone advertises a GATT service the Mac connects to:
/// - while waiting to be paired, it advertises ``pairingServiceUUID``;
/// - once paired, it advertises the pairing identifier as its service UUID, so a Mac only ever
///   connects to *its* iPhone (and the iPhone only answers *its* Mac).
public enum LockyBluetooth {
    /// Service advertised by an iPhone that is waiting to be paired with a Mac.
    public static let pairingServiceUUID: UUID = makeUUID("4C4F434B-5900-4B49-8000-000000000001")
    /// Characteristic the iPhone notifies to send data to the Mac.
    public static let toMacCharacteristicUUID: UUID = makeUUID("4C4F434B-5900-4B49-8000-000000000010")
    /// Characteristic the Mac writes to send data to the iPhone.
    public static let toPhoneCharacteristicUUID: UUID = makeUUID("4C4F434B-5900-4B49-8000-000000000011")
    /// Local name used in advertisements (only visible while the iPhone app is in foreground).
    public static let advertisedLocalName: String = "Locky"
    /// Restoration identifier for the iOS peripheral manager.
    public static let peripheralRestorationIdentifier: String = "studio.lunabee.locky.peripheral"
    /// Restoration identifier for the Mac central manager.
    public static let centralRestorationIdentifier: String = "studio.lunabee.locky.central"
    /// Interval between two heartbeats sent by the Mac.
    public static let heartbeatInterval: Duration = .seconds(2)
    /// Time without any data after which a link is considered dead.
    public static let heartbeatTimeout: Duration = .seconds(8)
    /// Lowest RSSI value considered by the proximity engine.
    public static let minimumRSSI: Double = -95

    private static func makeUUID(_ string: StaticString) -> UUID {
        guard let uuid = UUID(uuidString: "\(string)") else {
            preconditionFailure("Invalid UUID literal \(string)")
        }
        return uuid
    }
}
