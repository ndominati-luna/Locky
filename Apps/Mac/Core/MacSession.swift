import CryptoKit
import Foundation
import LockyKit
import Observation
import OSLog

/// Protocol layer of the Mac: pairing, secure sessions and message exchange with the iPhone.
@MainActor
@Observable
final class MacSession {
    private(set) var connection: MacConnectionState = .searching
    private(set) var pairingStep: MacPairingStep = .idle
    private(set) var pairing: PairingRecord?
    /// Model identifier of the iPhone being paired or paired.
    private(set) var peerModelIdentifier: String?

    @ObservationIgnored var onMessage: ((LockyMessage) -> Void)?
    @ObservationIgnored var onSessionOpened: (() -> Void)?
    @ObservationIgnored var onSessionClosed: (() -> Void)?
    /// Raw RSSI readings of the connected iPhone.
    @ObservationIgnored var onRSSI: ((Double) -> Void)?
    /// Pairing finished: preferences chosen on the iPhone.
    @ObservationIgnored var onPairingCompleted: ((PhonePreferences) -> Void)?
    /// The signal was measured again at 1 m and 2 m from the settings of the iPhone, saved in
    /// ``pairing``.
    @ObservationIgnored var onCalibrationChanged: (() -> Void)?

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "MacSession")
    private let vault: PairingVault = .init()
    private let link: MacLink
    private var pairingKey: SymmetricKey?
    private var channel: SecureChannel?
    private var pendingLocalNonce: Data?
    private var lastHandshakeRequest: ContinuousClock.Instant?
    private var heartbeatTask: Task<Void, Never>?
    private var context: PairingContext?
    private var passwordContinuation: CheckedContinuation<Bool, Never>?
    private var passwordAttempt: UUID?
    /// Distance being measured (pairing or settings), its readings, and the measures of the
    /// calibration in progress.
    private var measuringStep: CalibrationStep?
    private var measureSamples: [Double] = []
    private var calibrationMeasures: [CalibrationStep: Double] = [:]

    private struct PairingContext {
        var exchange: PairingKeyExchange
        var response: PairingResponse?
        var secret: PairingSecret?
        var pairingID: UUID?
        var isConfirmedOnMac: Bool = false
    }

    init() {
        let stored: (record: PairingRecord, key: SymmetricKey)? = vault.load()
        pairing = stored?.record
        pairingKey = stored?.key
        link = .init(serviceUUID: stored?.record.pairingID ?? LockyBluetooth.pairingServiceUUID, isPairingMode: false)
        link.knownPeripheral = UserDefaults.standard.string(forKey: Self.peripheralKey).flatMap(UUID.init(uuidString:))
        peerModelIdentifier = UserDefaults.standard.string(forKey: Self.peerModelKey)
        link.onStateChange = { [weak self] state in self?.linkStateChanged(state) }
        link.onConnect = { [weak self] identifier in self?.linkConnected(identifier) }
        link.onDisconnect = { [weak self] in self?.linkDisconnected() }
        link.onPayload = { [weak self] payload in self?.receive(payload) }
        link.onRSSI = { [weak self] rssi in self?.receivedRSSI(rssi) }
    }

    private static let peripheralKey: String = "locky.peripheralIdentifier"
    private static let peerModelKey: String = "locky.peerModelIdentifier"

    var isPaired: Bool {
        pairing != nil
    }

    var macID: UUID {
        vault.localIdentifier
    }

    var isBluetoothAvailable: Bool {
        link.isBluetoothAvailable
    }

    /// Starts looking for the paired iPhone.
    func start() {
        guard isPaired else { return }
        link.start()
    }

    /// Stops Bluetooth activity (sleep, user switch).
    func stop() {
        link.stop()
    }

    @discardableResult
    func send(_ message: LockyMessage) -> Bool {
        guard var channel else { return false }
        do {
            let payload: Data = try WireCodec.encodeEncrypted(message, channel: &channel)
            self.channel = channel
            link.send(payload)
            return true
        } catch {
            logger.error("Encryption failed: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Pairing

    /// Starts looking for an iPhone to pair (forgets any current pairing).
    func startPairing() {
        let wasConnected: Bool = isPaired && connection.isConnected
        if isPaired {
            unpair(notifyPhone: wasConnected)
        }
        context = nil
        channel = nil
        pairingStep = .searching
        Task {
            if wasConnected {
                // Let the unpair message reach the iPhone, otherwise it keeps advertising its
                // pairing specific service and never shows up in the pairing scan.
                try? await Task.sleep(for: .seconds(1))
            }
            guard pairingStep == .searching else { return }
            link.configure(serviceUUID: LockyBluetooth.pairingServiceUUID, isPairingMode: true)
            link.start()
        }
    }

    /// The found iPhone is the right one.
    func acceptFoundDevice() {
        guard var context, let response = context.response else { return }
        sendClearText(.pairingKeyReveal(.init(publicKey: context.exchange.publicKey, nonce: context.exchange.nonce)))
        do {
            let secret: PairingSecret = try context.exchange.deriveSecret(
                macPublicKey: context.exchange.publicKey,
                macNonce: context.exchange.nonce,
                phonePublicKey: response.publicKey,
                phoneNonce: response.nonce,
                macID: macID,
                deviceID: response.deviceID
            )
            context.secret = secret
            self.context = context
            channel = secret.makeChannel(role: .mac)
            updateCodeStep()
        } catch {
            fail(String(localized: "The key of the iPhone is invalid. Please try again."))
        }
    }

    /// The user checked that the iPhone displays the same code as the Mac.
    ///
    /// Required on the Mac too: a confirmation coming from the peer alone would let a rogue device
    /// impersonating the iPhone complete the pairing and receive the session password.
    func confirmCodeOnMac() {
        guard context?.secret != nil else { return }
        context?.isConfirmedOnMac = true
        updateCodeStep()
    }

    private func updateCodeStep() {
        guard let context, let secret = context.secret, let response = context.response else { return }
        let isConfirmedOnPhone: Bool = context.pairingID != nil
        if context.isConfirmedOnMac, isConfirmedOnPhone {
            pairingStep = .password(deviceName: response.deviceName)
        } else {
            pairingStep = .confirmCode(
                code: secret.verificationCode,
                deviceName: response.deviceName,
                isConfirmedOnMac: context.isConfirmedOnMac,
                isConfirmedOnPhone: isConfirmedOnPhone
            )
        }
    }

    /// The found iPhone is not the right one: look for another.
    func rejectFoundDevice() {
        context = nil
        channel = nil
        pairingStep = .searching
        link.rejectCurrentPeripheral()
    }

    /// Checks the session password and sends it to the iPhone keychain.
    /// - Returns: `false` when the password is wrong or the iPhone did not store it.
    func submitPassword(_ password: String) async -> Bool {
        if context != nil {
            // Never send the password to a device the user did not approve on the Mac.
            guard context?.isConfirmedOnMac == true, context?.pairingID != nil else { return false }
        }
        guard await PasswordVerifier.verify(password) else { return false }
        guard send(.storePassword(password)) else { return false }
        resolvePassword(false)
        let attempt: UUID = .init()
        passwordAttempt = attempt
        let stored: Bool = await withCheckedContinuation { continuation in
            passwordContinuation = continuation
            Task {
                try? await Task.sleep(for: .seconds(10))
                if passwordAttempt == attempt {
                    resolvePassword(false)
                }
            }
        }
        if stored, context != nil {
            // The user now puts the iPhone 1 m away, then 2 m, confirming each time on it
            // (calibrationRequest).
            pairingStep = .calibrating
        }
        return stored
    }

    /// Cancels an ongoing pairing.
    func cancelPairing() {
        context = nil
        calibrationMeasures = [:]
        channel = nil
        pairingStep = .idle
        if let pairing {
            link.configure(serviceUUID: pairing.pairingID, isPairingMode: false)
        } else {
            link.stop()
        }
    }

    /// Forgets the iPhone.
    func unpair(notifyPhone: Bool) {
        if notifyPhone {
            send(.unpair)
        }
        vault.clear()
        UserDefaults.standard.removeObject(forKey: Self.peripheralKey)
        UserDefaults.standard.removeObject(forKey: Self.peerModelKey)
        pairing = nil
        pairingKey = nil
        peerModelIdentifier = nil
        link.knownPeripheral = nil
        let link: MacLink = link
        Task {
            // Let the unpair message leave before cutting the link.
            try? await Task.sleep(for: .seconds(1))
            if !isPaired, pairingStep == .idle {
                link.stop()
            }
        }
        channel = nil
        pairingStep = .idle
        connection = .searching
    }

    // MARK: - Calibration

    /// The iPhone lies at the distance of `step` (the user confirmed on it): listens to the signal
    /// for a few seconds, then gives the median to the iPhone. During the pairing the measures go
    /// into the pairing record; from the settings they are saved once both distances are measured.
    private func measure(_ step: CalibrationStep) {
        guard measuringStep == nil, context != nil || isPaired else { return }
        if step == .near {
            calibrationMeasures = [:]
        }
        measuringStep = step
        measureSamples = []
        Task {
            try? await Task.sleep(for: CalibrationStep.measureDuration)
            finishMeasure()
        }
    }

    private func finishMeasure() {
        guard let step = measuringStep else { return }
        measuringStep = nil
        let samples: [Double] = measureSamples.sorted()
        measureSamples = []
        let rssi: Double
        if samples.count >= 4 {
            // The median is robust to the occasional deep fade.
            rssi = samples[samples.count / 2]
        } else if context != nil {
            // Pairing (link hiccup): typical values rather than a failed pairing.
            rssi = step == .near ? -65 : (calibrationMeasures[.near] ?? -65) - 6.6
        } else {
            // Settings: the link dropped meanwhile, the former calibration stays.
            calibrationMeasures = [:]
            return
        }
        calibrationMeasures[step] = rssi
        _ = send(.calibration(step, rssi: rssi))
        if context == nil, step == .far, let near = calibrationMeasures[.near] {
            saveCalibration(near: near, far: rssi)
        }
    }

    /// Calibrated again from the settings of the iPhone.
    private func saveCalibration(near: Double, far: Double) {
        calibrationMeasures = [:]
        guard var record = pairing else { return }
        record.calibrate(near: near, far: far)
        do {
            try vault.update(record: record)
        } catch {
            logger.error("Saving the calibration failed: \(error.localizedDescription)")
            return
        }
        pairing = record
        logger.info("Calibrated again: \(near) dBm at 1 m, \(far) dBm at 2 m")
        onCalibrationChanged?()
    }

    private func completePairing(preferences: PhonePreferences) {
        guard
            let context,
            let response = context.response,
            let secret = context.secret,
            let pairingID = context.pairingID
        else { return }
        var record: PairingRecord = .init(
            pairingID: pairingID,
            peerID: response.deviceID,
            peerName: response.deviceName,
            calibrationRSSI: nil,
            pairedAt: .now
        )
        if let near = calibrationMeasures[.near] {
            record.calibrate(near: near, far: calibrationMeasures[.far])
        }
        calibrationMeasures = [:]
        do {
            try vault.save(record: record, key: secret.key)
        } catch {
            fail(String(localized: "Locky could not save the pairing in the keychain."))
            return
        }
        pairing = record
        pairingKey = secret.key
        peerModelIdentifier = response.modelIdentifier
        UserDefaults.standard.set(response.modelIdentifier, forKey: Self.peerModelKey)
        self.context = nil
        pairingStep = .completed
        onPairingCompleted?(preferences)
        Task {
            try? await Task.sleep(for: .seconds(1))
            channel = nil
            link.configure(serviceUUID: pairingID, isPairingMode: false)
        }
    }

    private func fail(_ message: String) {
        context = nil
        channel = nil
        pairingStep = .failed(message)
        link.stop()
    }

    private func resolvePassword(_ stored: Bool) {
        passwordContinuation?.resume(returning: stored)
        passwordContinuation = nil
        passwordAttempt = nil
    }

    // MARK: - Link events

    private func linkStateChanged(_ state: MacLink.State) {
        switch state {
        case .poweredOff: connection = .bluetoothOff
        case .unauthorized: connection = .unauthorized
        case .unsupported: connection = .unsupported
        case .unknown, .idle, .scanning: connection = .searching
        case .connecting: connection = .connecting
        case .connected: connection = channel == nil ? .connecting : .connected
        }
    }

    private func linkConnected(_ identifier: UUID) {
        channel = nil
        pendingLocalNonce = nil
        connection = .connecting
        if pairingStep == .searching {
            let exchange: PairingKeyExchange = .init()
            context = .init(exchange: exchange)
            sendClearText(.pairingRequest(.init(
                macID: macID,
                macName: MacDeviceInfo.name,
                family: MacDeviceInfo.family,
                commitment: exchange.commitment
            )))
        } else if isPaired {
            UserDefaults.standard.set(identifier.uuidString, forKey: Self.peripheralKey)
            link.knownPeripheral = identifier
            requestSession(force: true)
        }
    }

    private func linkDisconnected() {
        let hadSession: Bool = channel != nil && isPaired && pairingStep != .calibrating
        channel = nil
        pendingLocalNonce = nil
        heartbeatTask?.cancel()
        if connection != .bluetoothOff, connection != .unauthorized {
            connection = .searching
        }
        switch pairingStep {
        case .deviceFound, .confirmCode, .password, .calibrating:
            if context != nil {
                resolvePassword(false)
                fail(String(localized: "The connection with the iPhone was lost. Keep both devices close and try again."))
            }
        default:
            break
        }
        if hadSession {
            onSessionClosed?()
        }
    }

    private func receivedRSSI(_ rssi: Double) {
        if measuringStep != nil {
            measureSamples.append(rssi)
        }
        onRSSI?(rssi)
    }

    // MARK: - Receiving

    private func receive(_ payload: Data) {
        let message: LockyMessage
        do {
            message = try WireCodec.decode(payload, channel: &channel)
            if !message.isHandshake {
                // Only authenticated messages prove the iPhone is still there.
                link.markAlive()
            }
        } catch LockyProtocolError.unknownMessage {
            // Sent by a newer Locky: authentic, the session goes on.
            link.markAlive()
            logger.notice("Unknown message ignored")
            return
        } catch {
            logger.notice("Undecodable payload: \(String(describing: error))")
            if isPaired, pairingStep == .idle || pairingStep == .completed {
                requestSession(force: false)
            }
            return
        }
        switch message {
        case let .pairingResponse(response):
            guard pairingStep == .searching, context != nil else { return }
            context?.response = response
            peerModelIdentifier = response.modelIdentifier
            pairingStep = .deviceFound(name: response.deviceName, modelIdentifier: response.modelIdentifier)
        case let .pairingConfirmed(confirmation):
            guard case .confirmCode = pairingStep else { return }
            context?.pairingID = confirmation.pairingID
            updateCodeStep()
        case .passwordStored:
            resolvePassword(true)
        case let .calibrationFinished(preferences):
            completePairing(preferences: preferences)
        case let .calibrationRequest(step):
            // During the pairing, or later from the settings of the iPhone.
            measure(step)
        case let .sessionHello(hello):
            handleSessionHello(hello)
        case .ping, .pairingRequest, .pairingKeyReveal, .storePassword, .calibration:
            break
        default:
            // Application messages only come from the paired iPhone, never from one being paired.
            guard isPaired, context == nil else { return }
            onMessage?(message)
        }
    }

    private func handleSessionHello(_ hello: SessionHello) {
        guard let pairing, let pairingKey, hello.participantID == pairing.peerID, hello.nonce.count == 32 else {
            logger.notice("Session hello from an unknown iPhone ignored")
            return
        }
        guard let echo = hello.echo else {
            // The iPhone asks for a new session (it lost its keys): the Mac always initiates.
            requestSession(force: false)
            return
        }
        // Only the answer to the latest initiation counts: stale answers are ignored.
        guard let pendingLocalNonce, echo == pendingLocalNonce else { return }
        self.pendingLocalNonce = nil
        channel = .init(pairingKey: pairingKey, macNonce: pendingLocalNonce, phoneNonce: hello.nonce, role: .mac)
        connection = .connected
        link.markAlive()
        startHeartbeat()
        onSessionOpened?()
    }

    private func requestSession(force: Bool) {
        guard link.isConnected else { return }
        if !force, let lastHandshakeRequest, ContinuousClock.now - lastHandshakeRequest < .seconds(2) { return }
        lastHandshakeRequest = .now
        channel = nil
        connection = .connecting
        let nonce: Data = .randomBytes(count: 32)
        pendingLocalNonce = nonce
        sendClearText(.sessionHello(.init(participantID: macID, nonce: nonce)))
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: LockyBluetooth.heartbeatInterval)
                guard let self, self.channel != nil else { return }
                self.send(.ping)
            }
        }
    }

    #if DEBUG
    /// Demo mode: shows a pairing step without any iPhone.
    func injectDemoPairingStep(_ step: MacPairingStep) {
        pairingStep = step
    }

    /// Demo mode (menu and widget reviews without an iPhone): pretends to be paired and connected.
    func injectDemoPairing(_ record: PairingRecord, modelIdentifier: String) {
        pairing = record
        peerModelIdentifier = modelIdentifier
        connection = .connected
    }
    #endif

    private func sendClearText(_ message: LockyMessage) {
        do {
            link.send(try WireCodec.encodeClearText(message))
        } catch {
            logger.error("Clear text encoding failed: \(error.localizedDescription)")
        }
    }
}
