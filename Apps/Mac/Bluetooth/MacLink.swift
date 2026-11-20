import CoreBluetooth
import Foundation
import LockyKit
import OSLog

/// Bluetooth transport of the Mac: a GATT central connected to the iPhone.
///
/// Stability notes (compared to the former implementation):
/// - only peripherals advertising the expected service are considered (the former app connected to
///   every Bluetooth device around and inspected its services);
/// - the last known iPhone is reconnected through a pending connection, which completes by itself as
///   soon as the iPhone is back in range, while scanning keeps running as a fallback;
/// - writes respect `canSendWriteWithoutResponse` flow control and the negotiated MTU;
/// - RSSI is read at a fixed pace instead of a tight loop;
/// - a watchdog drops half-open links when the iPhone stops answering heartbeats.
@MainActor
final class MacLink: NSObject {
    enum State: Equatable {
        case unknown
        case poweredOff
        case unauthorized
        case unsupported
        case idle
        case scanning
        case connecting
        case connected
    }

    /// A Locky iPhone found while pairing.
    struct Candidate: Equatable {
        let identifier: UUID
        let rssi: Double
    }

    var onStateChange: ((State) -> Void)?
    var onConnect: ((UUID) -> Void)?
    var onDisconnect: (() -> Void)?
    var onPayload: ((Data) -> Void)?
    var onRSSI: ((Double) -> Void)?

    private(set) var state: State = .unknown {
        didSet {
            guard oldValue != state else { return }
            onStateChange?(state)
        }
    }

    /// Peripherals ignored while pairing ("Not this one").
    var rejectedPeripherals: Set<UUID> = []
    /// Identifier of the paired iPhone, used for fast reconnections.
    var knownPeripheral: UUID?

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "MacLink")
    private var central: CBCentralManager?
    private var serviceUUID: CBUUID
    private var isPairingMode: Bool
    private var isRunning: Bool = false
    private var peripheral: CBPeripheral?
    private var toPhone: CBCharacteristic?
    private var assembler: FrameAssembler = .init()
    private var pendingChunks: [Data] = []
    private var lastActivity: ContinuousClock.Instant = .now
    private var candidates: [UUID: (peripheral: CBPeripheral, rssi: Double)] = [:]
    private var candidateTask: Task<Void, Never>?
    private var rssiTask: Task<Void, Never>?
    private var watchdogTask: Task<Void, Never>?
    private var connectTimeoutTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    /// iPhones reached without the Locky service (the app was closed): left alone until they
    /// advertise it again, or for half a minute (an app relaunched in background advertises in a
    /// way the Mac may not see), instead of being reconnected every second.
    private var peripheralsWithoutService: Set<UUID> = []
    private var serviceRetryTasks: [UUID: Task<Void, Never>] = [:]

    init(serviceUUID: UUID, isPairingMode: Bool) {
        self.serviceUUID = CBUUID(nsuuid: serviceUUID)
        self.isPairingMode = isPairingMode
        super.init()
    }

    var isConnected: Bool {
        state == .connected
    }

    /// Bluetooth radio usable.
    var isBluetoothAvailable: Bool {
        central?.state == .poweredOn
    }

    // MARK: - Control

    func start() {
        isRunning = true
        if central == nil {
            central = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: false])
        } else {
            connectOrScan()
        }
    }

    /// Stops everything (sleep, user switch, unpairing).
    func stop() {
        isRunning = false
        reconnectTask?.cancel()
        central?.stopScan()
        disconnect()
        state = isBluetoothAvailable ? .idle : state
    }

    /// Switches between the pairing service and a pairing specific service.
    func configure(serviceUUID: UUID, isPairingMode: Bool) {
        let newUUID: CBUUID = .init(nsuuid: serviceUUID)
        guard newUUID != self.serviceUUID || isPairingMode != self.isPairingMode else { return }
        self.serviceUUID = newUUID
        self.isPairingMode = isPairingMode
        rejectedPeripherals.removeAll()
        peripheralsWithoutService.removeAll()
        serviceRetryTasks.values.forEach { $0.cancel() }
        serviceRetryTasks.removeAll()
        disconnect()
        if isRunning {
            connectOrScan()
        }
    }

    /// Called by the session for every authenticated message: feeds the watchdog. Raw data does
    /// not count, so a rogue peripheral cannot keep a useless link alive.
    func markAlive() {
        lastActivity = .now
    }

    /// Drops the current connection; the link reconnects by itself when running.
    func disconnect() {
        candidateTask?.cancel()
        candidateTask = nil
        candidates.removeAll()
        if let peripheral {
            central?.cancelPeripheralConnection(peripheral)
        }
        cleanUpConnection(notify: true)
    }

    /// Rejects the current iPhone (pairing) and looks for another one.
    func rejectCurrentPeripheral() {
        if let identifier = peripheral?.identifier {
            rejectedPeripherals.insert(identifier)
        }
        disconnect()
        connectOrScan()
    }

    /// Sends one payload (framed and chunked here).
    func send(_ payload: Data) {
        guard let peripheral, toPhone != nil, state == .connected else { return }
        let chunkLength: Int = max(20, peripheral.maximumWriteValueLength(for: .withoutResponse))
        pendingChunks += FrameAssembler.chunks(for: payload, maximumChunkLength: chunkLength)
        flush()
    }

    // MARK: - Connection management

    private func connectOrScan() {
        guard isRunning, let central, central.state == .poweredOn, peripheral == nil else { return }
        if !isPairingMode, let knownPeripheral, !peripheralsWithoutService.contains(knownPeripheral),
           let known = central.retrievePeripherals(withIdentifiers: [knownPeripheral]).first {
            // Pending connection: completes as soon as the iPhone is reachable, never times out.
            connect(known)
        }
        if !isPairingMode,
           let alreadyConnected = central.retrieveConnectedPeripherals(withServices: [serviceUUID]).first,
           peripheral == nil {
            connect(alreadyConnected)
        }
        central.scanForPeripherals(withServices: [serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: isPairingMode])
        if peripheral == nil {
            state = .scanning
        }
    }

    private func connect(_ target: CBPeripheral) {
        guard let central else { return }
        if let peripheral, peripheral.identifier != target.identifier {
            central.cancelPeripheralConnection(peripheral)
        }
        peripheral = target
        target.delegate = self
        state = .connecting
        central.connect(target, options: nil)
        if isPairingMode {
            connectTimeoutTask?.cancel()
            connectTimeoutTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self, self.state == .connecting else { return }
                self.logger.notice("Connection attempt timed out")
                self.disconnect()
                self.scheduleReconnect()
            }
        }
    }

    /// Reconnects a moment after dropping a link: reconnecting the same iPhone at once would race
    /// with the cancellation, whose late disconnection event would then tear the new link down.
    private func scheduleReconnect(after delay: Duration = .seconds(1)) {
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.connectOrScan()
        }
    }

    private func linkReady(_ peripheral: CBPeripheral) {
        connectTimeoutTask?.cancel()
        central?.stopScan()
        assembler.reset()
        pendingChunks.removeAll()
        lastActivity = .now
        state = .connected
        startRSSIReadings()
        // While pairing, the user may take a while (code check, password): no heartbeat yet.
        if !isPairingMode {
            startWatchdog()
        }
        onConnect?(peripheral.identifier)
    }

    private func cleanUpConnection(notify: Bool) {
        let wasConnected: Bool = state == .connected
        rssiTask?.cancel()
        watchdogTask?.cancel()
        connectTimeoutTask?.cancel()
        peripheral?.delegate = nil
        peripheral = nil
        toPhone = nil
        assembler.reset()
        pendingChunks.removeAll()
        if central?.state == .poweredOn {
            state = .idle
        }
        if notify, wasConnected {
            onDisconnect?()
        }
    }

    private func flush() {
        guard let peripheral, let toPhone else {
            pendingChunks.removeAll()
            return
        }
        while let chunk = pendingChunks.first, peripheral.canSendWriteWithoutResponse {
            peripheral.writeValue(chunk, for: toPhone, type: .withoutResponse)
            pendingChunks.removeFirst()
        }
    }

    private func startRSSIReadings() {
        rssiTask?.cancel()
        rssiTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self, let peripheral = self.peripheral, peripheral.state == .connected else { return }
                peripheral.readRSSI()
                try? await Task.sleep(for: .milliseconds(300))
            }
        }
    }

    private func startWatchdog() {
        watchdogTask?.cancel()
        watchdogTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if ContinuousClock.now - self.lastActivity > LockyBluetooth.heartbeatTimeout {
                    self.logger.notice("Heartbeat timeout, reconnecting")
                    self.disconnect()
                    self.scheduleReconnect()
                    return
                }
            }
        }
    }

    /// While pairing, waits a moment to hear every iPhone around and picks the closest one.
    private func considerCandidate(_ peripheral: CBPeripheral, rssi: Double) {
        guard !rejectedPeripherals.contains(peripheral.identifier), rssi < 0 else { return }
        candidates[peripheral.identifier] = (peripheral, rssi)
        guard candidateTask == nil else { return }
        candidateTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled, let self else { return }
            self.candidateTask = nil
            guard self.peripheral == nil, let best = self.candidates.values.max(by: { $0.rssi < $1.rssi }) else { return }
            self.candidates.removeAll()
            self.connect(best.peripheral)
        }
    }

    // MARK: - Delegate handlers

    private func handleStateUpdate(_ newState: CBManagerState) {
        switch newState {
        case .poweredOn:
            state = .idle
            connectOrScan()
        case .poweredOff:
            cleanUpConnection(notify: true)
            state = .poweredOff
        case .unauthorized:
            cleanUpConnection(notify: true)
            state = .unauthorized
        case .unsupported:
            state = .unsupported
        default:
            // Resetting / unknown: every CBPeripheral is invalidated.
            cleanUpConnection(notify: true)
            state = .unknown
        }
    }

    private func handleDiscovery(_ discovered: CBPeripheral, rssi: Double, hasLocalName: Bool) {
        guard isRunning else { return }
        if isPairingMode {
            guard peripheral == nil else { return }
            considerCandidate(discovered, rssi: rssi)
            return
        }
        if peripheralsWithoutService.contains(discovered.identifier) {
            // iOS keeps advertising the service of a closed app (in background, without the name of
            // the advertisement), and the service is not there when connecting: wait for the retry
            // rather than reconnecting every second. Locky opened again advertises its name.
            guard hasLocalName else { return }
            peripheralsWithoutService.remove(discovered.identifier)
            serviceRetryTasks.removeValue(forKey: discovered.identifier)?.cancel()
        }
        // Without Bluetooth bonding the iPhone address rotates, so the identifier of a pending
        // connection may be stale: prefer the peripheral actually advertising the service.
        if let peripheral, peripheral.state == .connected || peripheral.identifier == discovered.identifier {
            return
        }
        connect(discovered)
    }

    private func handleDisconnection(_ disconnected: CBPeripheral, error: (any Error)?) {
        guard disconnected.identifier == peripheral?.identifier else { return }
        // Kept in the system log, to look into link losses afterwards.
        logger.notice("Disconnected: \(error?.localizedDescription ?? "no error", privacy: .public)")
        cleanUpConnection(notify: true)
        // Reconnect as soon as possible.
        scheduleReconnect(after: .milliseconds(500))
    }

    private func handleServices(_ target: CBPeripheral, error: (any Error)?) {
        guard target.identifier == peripheral?.identifier else { return }
        guard error == nil, let service = target.services?.first(where: { $0.uuid == serviceUUID }) else {
            // The iPhone itself answers even when Locky is not running: wait for the app to
            // advertise its service again rather than reconnecting right away.
            logger.notice("Locky service not found, waiting for the iPhone to advertise it")
            let identifier: UUID = target.identifier
            peripheralsWithoutService.insert(identifier)
            serviceRetryTasks[identifier]?.cancel()
            serviceRetryTasks[identifier] = Task { [weak self] in
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                self.serviceRetryTasks[identifier] = nil
                self.peripheralsWithoutService.remove(identifier)
                self.connectOrScan()
            }
            disconnect()
            scheduleReconnect()
            return
        }
        target.discoverCharacteristics(
            [CBUUID(nsuuid: LockyBluetooth.toMacCharacteristicUUID), CBUUID(nsuuid: LockyBluetooth.toPhoneCharacteristicUUID)],
            for: service
        )
    }

    private func handleCharacteristics(_ target: CBPeripheral, service: CBService, error: (any Error)?) {
        guard target.identifier == peripheral?.identifier else { return }
        guard error == nil else {
            disconnect()
            scheduleReconnect()
            return
        }
        let characteristics: [CBCharacteristic] = service.characteristics ?? []
        toPhone = characteristics.first { $0.uuid == CBUUID(nsuuid: LockyBluetooth.toPhoneCharacteristicUUID) }
        guard let toMac = characteristics.first(where: { $0.uuid == CBUUID(nsuuid: LockyBluetooth.toMacCharacteristicUUID) }), toPhone != nil else {
            disconnect()
            scheduleReconnect()
            return
        }
        target.setNotifyValue(true, for: toMac)
    }
}

// MARK: - CBCentralManagerDelegate

extension MacLink: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let state: CBManagerState = central.state
        MainActor.assumeIsolated { handleStateUpdate(state) }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        nonisolated(unsafe) let peripheral: CBPeripheral = peripheral
        let rssi: Double = RSSI.doubleValue
        let hasLocalName: Bool = advertisementData[CBAdvertisementDataLocalNameKey] != nil
        MainActor.assumeIsolated { handleDiscovery(peripheral, rssi: rssi, hasLocalName: hasLocalName) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        nonisolated(unsafe) let peripheral: CBPeripheral = peripheral
        MainActor.assumeIsolated {
            guard peripheral.identifier == self.peripheral?.identifier else { return }
            peripheral.discoverServices([serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: (any Error)?) {
        nonisolated(unsafe) let peripheral: CBPeripheral = peripheral
        MainActor.assumeIsolated { handleDisconnection(peripheral, error: error) }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: (any Error)?
    ) {
        nonisolated(unsafe) let peripheral: CBPeripheral = peripheral
        MainActor.assumeIsolated { handleDisconnection(peripheral, error: error) }
    }
}

// MARK: - CBPeripheralDelegate

extension MacLink: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: (any Error)?) {
        nonisolated(unsafe) let peripheral: CBPeripheral = peripheral
        MainActor.assumeIsolated { handleServices(peripheral, error: error) }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: (any Error)?
    ) {
        nonisolated(unsafe) let peripheral: CBPeripheral = peripheral
        nonisolated(unsafe) let service: CBService = service
        MainActor.assumeIsolated { handleCharacteristics(peripheral, service: service, error: error) }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        nonisolated(unsafe) let peripheral: CBPeripheral = peripheral
        let isNotifying: Bool = characteristic.isNotifying
        MainActor.assumeIsolated {
            guard peripheral.identifier == self.peripheral?.identifier else { return }
            if isNotifying, error == nil {
                linkReady(peripheral)
            } else {
                disconnect()
                scheduleReconnect()
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: (any Error)?
    ) {
        guard error == nil, let value = characteristic.value else { return }
        let identifier: UUID = peripheral.identifier
        MainActor.assumeIsolated {
            guard identifier == self.peripheral?.identifier else { return }
            do {
                for payload in try assembler.append(value) {
                    onPayload?(payload)
                }
            } catch {
                logger.error("Dropping malformed frame: \(error.localizedDescription)")
                assembler.reset()
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: (any Error)?) {
        guard error == nil else { return }
        let value: Double = RSSI.doubleValue
        MainActor.assumeIsolated { onRSSI?(value) }
    }

    nonisolated func peripheralIsReady(toSendWriteWithoutResponse peripheral: CBPeripheral) {
        MainActor.assumeIsolated { flush() }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
        let invalidated: [String] = invalidatedServices.map(\.uuid.uuidString)
        MainActor.assumeIsolated {
            // Only the Locky service matters (other apps of the iPhone may publish services too).
            guard invalidated.contains(serviceUUID.uuidString) else { return }
            // The iPhone switched to its pairing specific service (or was reset): reconnect.
            disconnect()
            scheduleReconnect()
        }
    }
}
