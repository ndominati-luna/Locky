import CryptoKit
import Foundation
import LockyKit
import Observation
import OSLog

/// Protocol layer of the iPhone: pairing, secure sessions and message exchange with the Mac.
@MainActor
@Observable
final class PhoneSession {
    private(set) var connection: ConnectionState = .searching
    private(set) var pairingStep: PairingStep = .waitingForMac
    private(set) var pairing: PairingRecord?

    /// Application level messages (everything but the handshake and pairing plumbing).
    @ObservationIgnored var onMessage: ((LockyMessage) -> Void)?
    /// Called each time a secure session opens.
    @ObservationIgnored var onSessionOpened: (() -> Void)?
    /// Called when the link drops.
    @ObservationIgnored var onSessionClosed: (() -> Void)?
    /// Called when the Mac finished measuring the signal at both distances: the app must calibrate
    /// motion and call ``completePairing(preferences:)``.
    @ObservationIgnored var onCalibrationRequested: ((Double) -> Void)?
    /// Called when the Mac sends the session password to store.
    @ObservationIgnored var onPasswordReceived: ((String) -> Bool)?
    /// Called on each heartbeat of the Mac (the app was woken up by Bluetooth).
    @ObservationIgnored var onHeartbeat: (() -> Void)?
    /// Called when the Mac measured the signal at a distance asked from the settings
    /// (``requestCalibration(_:)``); saved once both distances are measured.
    @ObservationIgnored var onCalibrationMeasured: ((CalibrationStep) -> Void)?

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "PhoneSession")
    private let vault: PairingVault = .init()
    private let link: PhoneLink
    /// Also seals the settings of the Mac left in iCloud (``MacSettingsEnvelope``).
    private(set) var pairingKey: SymmetricKey?
    private var channel: SecureChannel?
    private var lastHandshakeRequest: ContinuousClock.Instant?
    private var pairingContext: PairingContext?
    /// Settings: the 1 m measure, saved with the 2 m one.
    private var pendingNearCalibration: Double?

    private struct PairingContext {
        var request: PairingRequest
        var exchange: PairingKeyExchange
        var secret: PairingSecret?
        var pairingID: UUID?
        var calibration: [CalibrationStep: Double] = [:]
    }

    init() {
        let stored: (record: PairingRecord, key: SymmetricKey)? = vault.load()
        pairing = stored?.record
        pairingKey = stored?.key
        link = .init(serviceUUID: stored?.record.pairingID ?? LockyBluetooth.pairingServiceUUID)
        if stored != nil {
            pairingStep = .completed
        }
        link.onStateChange = { [weak self] state in self?.linkStateChanged(state) }
        link.onConnect = { [weak self] in self?.linkConnected() }
        link.onDisconnect = { [weak self] in self?.linkDisconnected() }
        link.onPayload = { [weak self] payload in self?.receive(payload) }
    }

    var isPaired: Bool {
        pairing != nil
    }

    /// Identifier of this iPhone for Locky.
    var deviceID: UUID {
        vault.localIdentifier
    }

    /// Starts Bluetooth.
    /// - Parameter dormant: Locky was closed by the user and iOS relaunched it in background: stay
    ///   silent (no service, no advertising) until it is opened.
    func start(dormant: Bool = false) {
        link.start(dormant: dormant)
    }

    /// The user closes Locky: the Mac can no longer reach it, and iOS no longer relaunches it.
    func withdraw() {
        link.withdraw()
    }

    /// Sends an encrypted message. Returns `false` when no session is open.
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

    /// Asks the Mac to measure the signal again, the iPhone lying at the distance of `step`.
    /// `false` without session.
    func requestCalibration(_ step: CalibrationStep) -> Bool {
        if step == .near {
            pendingNearCalibration = nil
        }
        return isPaired && send(.calibrationRequest(step))
    }

    /// Pairing: the iPhone lies at the distance of the current step, the user confirmed: the Mac
    /// measures the signal (after the last step, the iPhone calibrates its motion sensors).
    func startPairingCalibration() {
        guard pairingContext != nil, case let .calibrating(step) = pairingStep, send(.calibrationRequest(step)) else { return }
        pairingStep = .measuring(step)
    }

    /// The user confirmed the verification code.
    func confirmPairingCode() {
        guard var context = pairingContext, context.secret != nil else { return }
        let pairingID: UUID = .init()
        context.pairingID = pairingID
        pairingContext = context
        send(.pairingConfirmed(.init(pairingID: pairingID)))
        pairingStep = .waitingForPassword(macName: context.request.macName)
    }

    /// The user rejected the verification code or cancelled.
    func cancelPairing() {
        pairingContext = nil
        channel = nil
        pairingStep = isPaired ? .completed : .waitingForMac
        link.resetConnection()
    }

    /// Ends the pairing once the motion calibration is done.
    func completePairing(preferences: PhonePreferences) {
        guard
            let context = pairingContext,
            let secret = context.secret,
            let pairingID = context.pairingID
        else { return }
        send(.calibrationFinished(preferences))
        var record: PairingRecord = .init(
            pairingID: pairingID,
            peerID: context.request.macID,
            peerName: context.request.macName,
            calibrationRSSI: nil,
            pairedAt: .now
        )
        if let near = context.calibration[.near] {
            record.calibrate(near: near, far: context.calibration[.far])
        }
        do {
            try vault.save(record: record, key: secret.key)
        } catch {
            logger.error("Saving the pairing failed: \(error.localizedDescription)")
            pairingStep = .failed(String(localized: "Locky could not save the pairing. Please try again."))
            return
        }
        pairing = record
        pairingKey = secret.key
        pairingContext = nil
        pairingStep = .completed
        // Let the last message leave before switching to the pairing specific service.
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            channel = nil
            link.updateServiceUUID(pairingID)
        }
    }

    /// Forgets the Mac.
    func unpair(notifyMac: Bool) {
        if notifyMac {
            send(.unpair)
        }
        Task {
            if notifyMac {
                try? await Task.sleep(for: .seconds(1))
            }
            vault.clear()
            pairing = nil
            pairingKey = nil
            channel = nil
            pairingContext = nil
            pairingStep = .waitingForMac
            connection = .searching
            link.updateServiceUUID(LockyBluetooth.pairingServiceUUID)
        }
    }

    // MARK: - Link events

    private func linkStateChanged(_ state: PhoneLink.State) {
        switch state {
        case .poweredOff: connection = .bluetoothOff
        case .unauthorized: connection = .unauthorized
        case .unsupported: connection = .unsupported
        case .unknown, .advertising: connection = .searching
        case .connected: connection = channel == nil ? .connecting : .connected
        }
    }

    private func linkConnected() {
        channel = nil
        connection = .connecting
        guard isPaired else { return }
        // The Mac opens the session; if it does not (e.g. after a restoration), ask for one.
        Task {
            try? await Task.sleep(for: .seconds(3))
            if link.isConnected, channel == nil {
                requestSession()
            }
        }
    }

    private func linkDisconnected() {
        let hadSession: Bool = channel != nil
        channel = nil
        if !isPaired, pairingContext != nil, pairingStep != .completed {
            pairingContext = nil
            pairingStep = .waitingForMac
        }
        if connection != .bluetoothOff, connection != .unauthorized {
            connection = .searching
        }
        if hadSession {
            onSessionClosed?()
        }
    }

    // MARK: - Receiving

    private func receive(_ payload: Data) {
        let message: LockyMessage
        do {
            message = try WireCodec.decode(payload, channel: &channel)
            if !message.isHandshake {
                // Only authenticated messages prove the Mac is still there.
                link.markAlive()
            }
        } catch LockyProtocolError.unknownMessage {
            // Sent by a newer Locky: authentic, the session goes on.
            link.markAlive()
            logger.notice("Unknown message ignored")
            return
        } catch {
            logger.notice("Undecodable payload: \(String(describing: error))")
            if isPaired {
                requestSession()
            }
            return
        }
        switch message {
        case let .pairingRequest(request):
            handlePairingRequest(request)
        case let .pairingKeyReveal(reveal):
            handleKeyReveal(reveal)
        case let .sessionHello(hello):
            handleSessionHello(hello)
        case let .storePassword(password):
            let stored: Bool = onPasswordReceived?(password) ?? false
            if stored {
                send(.passwordStored)
                if pairingContext != nil {
                    pairingStep = .calibrating(.near)
                }
            }
        case let .calibration(step, rssi):
            if pairingContext != nil {
                pairingContext?.calibration[step] = rssi
                switch step {
                case .near:
                    pairingStep = .calibrating(.far)
                case .far:
                    onCalibrationRequested?(rssi)
                }
            } else if isPaired {
                // Measured again from the settings.
                switch step {
                case .near:
                    pendingNearCalibration = rssi
                case .far:
                    if let near = pendingNearCalibration, var record = pairing {
                        record.calibrate(near: near, far: rssi)
                        do {
                            try vault.update(record: record)
                            pairing = record
                        } catch {
                            logger.error("Saving the calibration failed: \(error.localizedDescription)")
                        }
                    }
                    pendingNearCalibration = nil
                }
                onCalibrationMeasured?(step)
            }
        case .ping:
            send(.ping)
            onHeartbeat?()
        case .pairingResponse, .pairingConfirmed, .passwordStored, .calibrationFinished:
            break
        default:
            // Application messages only come from the paired Mac, never from a Mac being paired.
            guard isPaired, pairingContext == nil else { return }
            onMessage?(message)
        }
    }

    private func handlePairingRequest(_ request: PairingRequest) {
        guard !isPaired else { return }
        let exchange: PairingKeyExchange = .init()
        pairingContext = .init(request: request, exchange: exchange)
        let response: PairingResponse = .init(
            deviceID: deviceID,
            deviceName: LocalDevice.name,
            deviceModel: LocalDevice.model,
            modelIdentifier: LocalDevice.modelIdentifier,
            publicKey: exchange.publicKey,
            nonce: exchange.nonce
        )
        sendClearText(.pairingResponse(response))
        pairingStep = .macFound(name: request.macName, family: request.family)
    }

    private func handleKeyReveal(_ reveal: PairingKeyReveal) {
        guard var context = pairingContext else { return }
        guard PairingKeyExchange.commitment(publicKey: reveal.publicKey, nonce: reveal.nonce) == context.request.commitment else {
            logger.error("Pairing commitment mismatch")
            pairingStep = .failed(String(localized: "The Mac key does not match. Please restart the pairing."))
            pairingContext = nil
            return
        }
        do {
            let secret: PairingSecret = try context.exchange.deriveSecret(
                macPublicKey: reveal.publicKey,
                macNonce: reveal.nonce,
                phonePublicKey: context.exchange.publicKey,
                phoneNonce: context.exchange.nonce,
                macID: context.request.macID,
                deviceID: deviceID
            )
            context.secret = secret
            pairingContext = context
            channel = secret.makeChannel(role: .phone)
            pairingStep = .confirmCode(code: secret.verificationCode, macName: context.request.macName)
        } catch {
            pairingStep = .failed(String(localized: "The pairing failed. Please restart it from your Mac."))
            pairingContext = nil
        }
    }

    private func handleSessionHello(_ hello: SessionHello) {
        guard let pairing, let pairingKey, hello.participantID == pairing.peerID, hello.nonce.count == 32 else {
            logger.notice("Session hello from an unknown Mac ignored")
            return
        }
        // The iPhone only answers: hellos carrying an echo are answers meant for the Mac.
        guard hello.echo == nil else { return }
        let localNonce: Data = .randomBytes(count: 32)
        sendClearText(.sessionHello(.init(participantID: deviceID, nonce: localNonce, echo: hello.nonce)))
        channel = .init(pairingKey: pairingKey, macNonce: hello.nonce, phoneNonce: localNonce, role: .phone)
        connection = .connected
        link.markAlive()
        onSessionOpened?()
    }

    /// Asks the Mac to open a new session (rate limited). Only the Mac initiates sessions.
    private func requestSession() {
        guard link.isConnected else { return }
        if let lastHandshakeRequest, ContinuousClock.now - lastHandshakeRequest < .seconds(2) { return }
        lastHandshakeRequest = .now
        channel = nil
        connection = .connecting
        sendClearText(.sessionHello(.init(participantID: deviceID, nonce: .randomBytes(count: 32))))
    }

    #if DEBUG
    func injectDemoPairingStep(_ step: PairingStep) {
        pairingStep = step
    }

    /// Demo mode (screenshots, previews): pretends to be paired and connected (or out of reach).
    func injectDemoPairing(_ record: PairingRecord) {
        pairing = record
        pairingStep = .completed
        connection = DemoMode.isOutOfReach ? .searching : .connected
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
