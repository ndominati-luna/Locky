#if os(iOS) || os(macOS)
import CoreBluetooth
import Foundation

/// Listens to the Bluetooth Low Energy advertisements around, for a ``WaveScan``: every device that
/// advertises, with the strength of its signal.
///
/// A central of its own, apart from the link of Locky: it only listens (it never connects), while
/// the app is in the foreground (iOS hears nothing in the background without a service to look
/// for).
@MainActor
public final class BluetoothNeighborScanner: NSObject {
    private struct Sighting {
        var name: String?
        var rssis: [Int] = []
        var strongest: Int = .min
        var count: Int = 0
        var companyID: UInt16?
        var serviceUUIDs: Set<String> = []
        var isConnectable: Bool?
        var txPower: Int?
    }

    /// Advertisement fields kept, read off the delegate callback.
    private struct Advertisement: Sendable {
        var name: String?
        var companyID: UInt16?
        var serviceUUIDs: [String]
        var isConnectable: Bool?
        var txPower: Int?
    }

    /// Devices kept, the strongest: enough for any room, and the part stays small in iCloud.
    public static let maximumDevices: Int = 250

    private var central: CBCentralManager?
    private var sightings: [UUID: Sighting] = [:]
    private var isScanning: Bool = false

    override public init() {
        super.init()
    }

    /// Starts listening (Bluetooth turns on or is allowed in the meantime: it starts then).
    public func start() {
        sightings = [:]
        isScanning = true
        if let central {
            startScanning(central)
        } else {
            central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        }
    }

    /// Stops listening and returns the devices heard, strongest first.
    public func stop() -> [BluetoothNeighbor] {
        isScanning = false
        if central?.state == .poweredOn {
            central?.stopScan()
        }
        let devices: [BluetoothNeighbor] = sightings.map { identifier, sighting in
            let sorted: [Int] = sighting.rssis.sorted()
            return .init(
                id: identifier.uuidString,
                name: sighting.name,
                rssi: sorted.isEmpty ? sighting.strongest : sorted[sorted.count / 2],
                strongestRSSI: sighting.strongest,
                sightings: sighting.count,
                companyID: sighting.companyID,
                serviceUUIDs: sighting.serviceUUIDs.sorted(),
                isConnectable: sighting.isConnectable,
                txPower: sighting.txPower
            )
        }
        return Array(devices.sorted { $0.rssi > $1.rssi }.prefix(Self.maximumDevices))
    }

    /// `false` while Bluetooth is off or not allowed.
    public var isAvailable: Bool {
        central?.state == .poweredOn
    }

    private func startScanning(_ central: CBCentralManager) {
        guard isScanning, central.state == .poweredOn, !central.isScanning else { return }
        central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }

    private func record(_ identifier: UUID, rssi: Int, advertisement: Advertisement) {
        // 127 means unknown; anything above 0 is noise.
        guard isScanning, rssi < 0, rssi > -127 else { return }
        var sighting: Sighting = sightings[identifier] ?? .init()
        sighting.count += 1
        sighting.strongest = max(sighting.strongest, rssi)
        // A rolling window: devices heard hundreds of times keep their latest readings.
        sighting.rssis.append(rssi)
        if sighting.rssis.count > 60 {
            sighting.rssis.removeFirst()
        }
        sighting.name = advertisement.name ?? sighting.name
        sighting.companyID = advertisement.companyID ?? sighting.companyID
        sighting.serviceUUIDs.formUnion(advertisement.serviceUUIDs)
        sighting.isConnectable = advertisement.isConnectable ?? sighting.isConnectable
        sighting.txPower = advertisement.txPower ?? sighting.txPower
        sightings[identifier] = sighting
    }

    nonisolated private static func advertisement(_ data: [String: Any], peripheralName: String?) -> Advertisement {
        var companyID: UInt16?
        if let manufacturer = data[CBAdvertisementDataManufacturerDataKey] as? Data, manufacturer.count >= 2 {
            companyID = UInt16(manufacturer[manufacturer.startIndex]) | UInt16(manufacturer[manufacturer.startIndex + 1]) << 8
        }
        let services: [CBUUID] = (data[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            + (data[CBAdvertisementDataOverflowServiceUUIDsKey] as? [CBUUID] ?? [])
        let name: String? = (data[CBAdvertisementDataLocalNameKey] as? String) ?? peripheralName
        return .init(
            name: name.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 },
            companyID: companyID,
            serviceUUIDs: services.map(\.uuidString),
            isConnectable: (data[CBAdvertisementDataIsConnectable] as? NSNumber)?.boolValue,
            txPower: (data[CBAdvertisementDataTxPowerLevelKey] as? NSNumber)?.intValue
        )
    }
}

extension BluetoothNeighborScanner: CBCentralManagerDelegate {
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        nonisolated(unsafe) let central: CBCentralManager = central
        MainActor.assumeIsolated { startScanning(central) }
    }

    nonisolated public func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        let identifier: UUID = peripheral.identifier
        let rssi: Int = RSSI.intValue
        let advertisement: Advertisement = Self.advertisement(advertisementData, peripheralName: peripheral.name)
        MainActor.assumeIsolated { record(identifier, rssi: rssi, advertisement: advertisement) }
    }
}
#endif
