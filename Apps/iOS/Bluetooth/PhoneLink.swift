import CoreBluetooth
import Foundation
import LockyKit
import OSLog

/// Bluetooth transport of the iPhone: a GATT peripheral the Mac connects to.
///
/// Stability notes (compared to the former implementation):
/// - frames are length prefixed and sized with the negotiated MTU, no in-band "EOD" marker;
/// - outgoing chunks wait for `peripheralManagerIsReady(toUpdateSubscribers:)` instead of being lost;
/// - advertising stops while connected and restarts as soon as the link drops (no busy waiting);
/// - a watchdog detects half-open links when the Mac stops sending heartbeats;
/// - state restoration lets iOS relaunch Locky in background to keep the link alive.
@MainActor
final class PhoneLink: NSObject {
    /// Bluetooth availability as seen by the app.
    enum State: Equatable {
        case unknown
        case poweredOff
        case unauthorized
        case unsupported
        case advertising
        case connected
    }

    var onStateChange: ((State) -> Void)?
    var onConnect: (() -> Void)?
    var onDisconnect: (() -> Void)?
    var onPayload: ((Data) -> Void)?

    private(set) var state: State = .unknown {
        didSet {
            guard oldValue != state else { return }
            onStateChange?(state)
        }
    }

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "PhoneLink")
    private var manager: CBPeripheralManager?
    private var serviceUUID: CBUUID
    private var service: CBMutableService?
    private var toMacCharacteristic: CBMutableCharacteristic?
    private var central: CBCentral?
    private var assembler: FrameAssembler = .init()
    private var pendingChunks: [Data] = []
    private var lastActivity: ContinuousClock.Instant = .now
    private var watchdog: Task<Void, Never>?
    /// The user closed Locky from the app switcher: iOS still advertises its service and relaunches
    /// it when the Mac connects. Dormant, the link withdraws everything until Locky is opened again.
    private var isDormant: Bool = false

    init(serviceUUID: UUID) {
        self.serviceUUID = CBUUID(nsuuid: serviceUUID)
        super.init()
    }

    /// `true` while a Mac is subscribed.
    var isConnected: Bool {
        central != nil
    }

    /// Creates the peripheral manager (triggers the Bluetooth permission prompt the first time).
    /// - Parameter dormant: relaunched in background after the user closed Locky: withdraw the
    ///   service iOS kept advertising instead of publishing it.
    func start(dormant: Bool = false) {
        isDormant = dormant
        guard manager == nil else {
            if dormant {
                withdraw()
            } else {
                publishService()
            }
            return
        }
        manager = CBPeripheralManager(
            delegate: self,
            queue: nil,
            options: [
                CBPeripheralManagerOptionRestoreIdentifierKey: LockyBluetooth.peripheralRestorationIdentifier,
                CBPeripheralManagerOptionShowPowerAlertKey: true
            ]
        )
    }

    /// Switches the advertised service (pairing service ↔ pairing specific service).
    func updateServiceUUID(_ uuid: UUID) {
        let newUUID: CBUUID = .init(nsuuid: uuid)
        guard newUUID != serviceUUID else { return }
        logger.info("Service UUID changes to \(uuid.uuidString)")
        serviceUUID = newUUID
        dropCentral(notify: true)
        publishService()
    }

    /// Sends one payload (it is framed and chunked here).
    func send(_ payload: Data) {
        guard let central else { return }
        let chunkLength: Int = max(20, central.maximumUpdateValueLength)
        pendingChunks += FrameAssembler.chunks(for: payload, maximumChunkLength: chunkLength)
        flush()
    }

    /// Called by the session for every authenticated message: feeds the watchdog. Raw data does
    /// not count, so a rogue central cannot keep a dead link alive.
    func markAlive() {
        lastActivity = .now
    }

    /// The user closed Locky: no more service nor advertising, so neither the Mac reconnects nor iOS
    /// relaunches the app for it.
    func withdraw() {
        isDormant = true
        dropCentral(notify: true)
        service = nil
        toMacCharacteristic = nil
        guard let manager else { return }
        manager.stopAdvertising()
        manager.removeAllServices()
        logger.notice("Service withdrawn: Locky was closed")
    }

    /// Forgets the current Mac (e.g. after an unpairing) and advertises again.
    func resetConnection() {
        dropCentral(notify: true)
        startAdvertisingIfPossible()
    }

    // MARK: - Private

    private func flush() {
        guard let manager, let toMacCharacteristic, let central else {
            pendingChunks.removeAll()
            return
        }
        while let chunk = pendingChunks.first {
            guard manager.updateValue(chunk, for: toMacCharacteristic, onSubscribedCentrals: [central]) else {
                // Transmit queue full: resumed by peripheralManagerIsReady(toUpdateSubscribers:).
                return
            }
            pendingChunks.removeFirst()
        }
    }

    private func publishService() {
        guard !isDormant, let manager, manager.state == .poweredOn else { return }
        manager.stopAdvertising()
        manager.removeAllServices()
        let toMac: CBMutableCharacteristic = .init(
            type: CBUUID(nsuuid: LockyBluetooth.toMacCharacteristicUUID),
            properties: [.notify],
            value: nil,
            permissions: [.readable]
        )
        let toPhone: CBMutableCharacteristic = .init(
            type: CBUUID(nsuuid: LockyBluetooth.toPhoneCharacteristicUUID),
            properties: [.write, .writeWithoutResponse],
            value: nil,
            permissions: [.writeable]
        )
        let service: CBMutableService = .init(type: serviceUUID, primary: true)
        service.characteristics = [toMac, toPhone]
        self.service = service
        toMacCharacteristic = toMac
        manager.add(service)
    }

    private func startAdvertisingIfPossible() {
        guard !isDormant, let manager, manager.state == .poweredOn, service != nil, central == nil else { return }
        if !manager.isAdvertising {
            manager.startAdvertising([
                CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
                CBAdvertisementDataLocalNameKey: LockyBluetooth.advertisedLocalName
            ])
        }
        state = .advertising
    }

    private func adopt(_ newCentral: CBCentral) {
        guard !isDormant else { return }
        if let central, central.identifier != newCentral.identifier {
            logger.info("Replacing central \(central.identifier) by \(newCentral.identifier)")
            dropCentral(notify: true)
        }
        guard central == nil else { return }
        central = newCentral
        assembler.reset()
        pendingChunks.removeAll()
        lastActivity = .now
        manager?.stopAdvertising()
        state = .connected
        // While pairing, the Mac sends no heartbeat (the user checks the code, types a password).
        if serviceUUID != CBUUID(nsuuid: LockyBluetooth.pairingServiceUUID) {
            startWatchdog()
        }
        onConnect?()
    }

    private func dropCentral(notify: Bool) {
        guard let dropped = central else { return }
        // Kept in the system log, to look into link losses afterwards.
        logger.notice("Mac \(dropped.identifier, privacy: .public) dropped")
        central = nil
        assembler.reset()
        pendingChunks.removeAll()
        watchdog?.cancel()
        watchdog = nil
        if notify {
            onDisconnect?()
        }
    }

    private func startWatchdog() {
        watchdog?.cancel()
        watchdog = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if ContinuousClock.now - self.lastActivity > LockyBluetooth.heartbeatTimeout {
                    self.logger.notice("Heartbeat timeout, link considered lost")
                    self.dropCentral(notify: true)
                    self.startAdvertisingIfPossible()
                    return
                }
            }
        }
    }

    private func handleStateUpdate(_ newState: CBManagerState) {
        switch newState {
        case .poweredOn:
            if isDormant {
                withdraw()
            } else if service == nil {
                publishService()
            } else {
                startAdvertisingIfPossible()
            }
        case .poweredOff:
            dropCentral(notify: true)
            service = nil
            state = .poweredOff
        case .unauthorized:
            dropCentral(notify: true)
            state = .unauthorized
        case .unsupported:
            state = .unsupported
        default:
            // Resetting / unknown: CoreBluetooth drops the GATT database, publish again once powered on.
            dropCentral(notify: true)
            service = nil
            state = .unknown
        }
    }

    private func handleWrites(_ requests: [CBATTRequest], manager: CBPeripheralManager) {
        guard !isDormant else { return }
        // A Mac still subscribed but dropped by the watchdog (the app was suspended a little too
        // long, the Mac was busy): it is obviously there, take it back rather than ignoring it until
        // it reconnects.
        if central == nil,
           let writer = requests.first?.central,
           toMacCharacteristic?.subscribedCentrals?.contains(where: { $0.identifier == writer.identifier }) == true {
            logger.notice("Mac \(writer.identifier, privacy: .public) still subscribed, taken back")
            adopt(writer)
        }
        for request in requests {
            // Only the subscribed Mac may talk to us: a write never replaces it.
            guard
                request.characteristic.uuid == CBUUID(nsuuid: LockyBluetooth.toPhoneCharacteristicUUID),
                let value = request.value,
                request.central.identifier == central?.identifier
            else { continue }
            do {
                for payload in try assembler.append(value) {
                    onPayload?(payload)
                }
            } catch {
                logger.error("Dropping malformed frame: \(error.localizedDescription)")
                assembler.reset()
            }
        }
        if let first = requests.first {
            manager.respond(to: first, withResult: .success)
        }
    }

    private func handleRestoration(_ dict: [String: Any]) {
        // Closed by the user: the restored service is withdrawn once powered on.
        guard !isDormant else { return }
        guard let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService] else { return }
        logger.info("Restoring \(services.count) service(s)")
        guard let restored = services.first(where: { $0.uuid == serviceUUID }) else { return }
        service = restored
        toMacCharacteristic = restored.characteristics?
            .compactMap { $0 as? CBMutableCharacteristic }
            .first { $0.uuid == CBUUID(nsuuid: LockyBluetooth.toMacCharacteristicUUID) }
        if let subscribed = toMacCharacteristic?.subscribedCentrals?.first {
            adopt(subscribed)
        }
    }
}

// MARK: - CBPeripheralManagerDelegate

extension PhoneLink: CBPeripheralManagerDelegate {
    nonisolated func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        let newState: CBManagerState = peripheral.state
        MainActor.assumeIsolated { handleStateUpdate(newState) }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String: Any]) {
        nonisolated(unsafe) let dict: [String: Any] = dict
        MainActor.assumeIsolated { handleRestoration(dict) }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: (any Error)?) {
        MainActor.assumeIsolated {
            if let error {
                logger.error("Adding service failed: \(error.localizedDescription)")
                return
            }
            startAdvertisingIfPossible()
        }
    }

    nonisolated func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: (any Error)?) {
        guard let error else { return }
        MainActor.assumeIsolated { logger.error("Advertising failed: \(error.localizedDescription)") }
    }

    nonisolated func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didSubscribeTo characteristic: CBCharacteristic
    ) {
        nonisolated(unsafe) let central: CBCentral = central
        MainActor.assumeIsolated { adopt(central) }
    }

    nonisolated func peripheralManager(
        _ peripheral: CBPeripheralManager,
        central: CBCentral,
        didUnsubscribeFrom characteristic: CBCharacteristic
    ) {
        let identifier: UUID = central.identifier
        MainActor.assumeIsolated {
            guard self.central?.identifier == identifier else { return }
            dropCentral(notify: true)
            startAdvertisingIfPossible()
        }
    }

    nonisolated func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        nonisolated(unsafe) let requests: [CBATTRequest] = requests
        nonisolated(unsafe) let peripheral: CBPeripheralManager = peripheral
        MainActor.assumeIsolated { handleWrites(requests, manager: peripheral) }
    }

    nonisolated func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        MainActor.assumeIsolated { flush() }
    }
}
