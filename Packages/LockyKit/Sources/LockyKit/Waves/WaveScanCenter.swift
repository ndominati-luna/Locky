import CryptoKit
import Foundation
import Observation
import OSLog

/// What a device needs to read and seal the measurements of its pairing.
public struct WaveScanCredentials: Sendable {
    public var key: SymmetricKey
    public var macID: UUID

    public init(key: SymmetricKey, macID: UUID) {
        self.key = key
        self.macID = macID
    }
}

/// A measurement under way on this device.
public struct WaveScanRun: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var date: Date
    /// When this device started listening (its own clock).
    public var startedAt: Date
    /// Started here rather than on the other device.
    public var isStartedHere: Bool

    public init(id: UUID, name: String, date: Date, startedAt: Date, isStartedHere: Bool) {
        self.id = id
        self.name = name
        self.date = date
        self.startedAt = startedAt
        self.isStartedHere = isStartedHere
    }

    /// When this device stops listening.
    public var endsAt: Date {
        startedAt.addingTimeInterval(TimeInterval(WaveScan.captureDuration.components.seconds))
    }
}

/// Where the measurement of this device stands.
public enum WaveScanPhase: Sendable, Equatable {
    case idle
    /// Listening, for ``WaveScan/captureDuration``.
    case measuring(WaveScanRun)
    /// Leaving its part in iCloud, then waiting a little for the part of the other device.
    case saving(WaveScanRun)
    /// The measurement is in the list.
    case finished(id: UUID)
    case failed(WaveScanFailure)

    public var run: WaveScanRun? {
        switch self {
        case let .measuring(run), let .saving(run): run
        case .idle, .finished, .failed: nil
        }
    }
}

public enum WaveScanFailure: Sendable, Equatable {
    /// No iCloud account: the measurement cannot be kept.
    case iCloudUnavailable
    /// iCloud refused it (network, quota…).
    case notSaved
}

/// The measurements of the waves around (``WaveScan``), read from iCloud, and the one under way on
/// this device, coordinated with the other one over Bluetooth (``WaveScanSignal``).
///
/// The app plugs in how to talk to the other device, the pairing key, and how this device listens
/// (``captureHandler``); the rest is the same on the Mac and on the iPhone.
@MainActor
@Observable
public final class WaveScanCenter {
    /// Measurements of the paired Mac, newest first.
    public private(set) var scans: [WaveScan] = []
    public private(set) var isLoading: Bool = false
    /// `false` without an iCloud account.
    public private(set) var isCloudAvailable: Bool = true
    /// The list was read from iCloud at least once.
    public private(set) var hasLoaded: Bool = false
    public private(set) var phase: WaveScanPhase = .idle
    /// The other device stopped or could not take part in the current measurement.
    public private(set) var isPeerMissing: Bool = false
    public let side: WaveScanSide

    /// Sends a signal to the other device; `false` when it could not be sent (out of reach).
    @ObservationIgnored public var sendSignal: @MainActor (WaveScanSignal) -> Bool = { _ in false }
    /// The pairing key and the Mac, `nil` when not paired.
    @ObservationIgnored public var credentials: @MainActor () -> WaveScanCredentials? = { nil }
    /// Listens for ``WaveScan/captureDuration`` and returns what this device heard; stops early
    /// when its task is cancelled.
    @ObservationIgnored public var captureHandler: (@MainActor (WaveScanRun) async -> WaveScanPart.Capture)?
    /// The device takes part in a measurement started on the other one (the iPhone only while
    /// Locky is on its screen).
    @ObservationIgnored public var canTakePart: @MainActor () -> Bool = { true }
    /// A measurement started on the other device (to show it).
    @ObservationIgnored public var onRemoteStart: (@MainActor (WaveScanRun) -> Void)?

    @ObservationIgnored private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "Waves")
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored private var savedByPeer: Set<UUID> = []
    @ObservationIgnored private var declinedByPeer: Set<UUID> = []
    /// Sample measurements are shown: iCloud is left alone.
    @ObservationIgnored private var isDemo: Bool = false
    /// When the last measurement stopped listening.
    @ObservationIgnored public private(set) var lastMeasurementEnd: ContinuousClock.Instant?

    /// How long the part of the other device is awaited once this one is saved.
    private static let peerWait: Duration = .seconds(30)

    public init(side: WaveScanSide) {
        self.side = side
    }

    /// Listening right now.
    public var isMeasuring: Bool {
        if case .measuring = phase { true } else { false }
    }

    public func scan(id: UUID) -> WaveScan? {
        scans.first { $0.id == id }
    }

    // MARK: - List

    /// Reads the measurements of the paired Mac from iCloud.
    public func refresh() async {
        guard !isDemo else { return }
        guard let credentials = credentials() else {
            scans = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        guard await CloudSync.shared.isAvailable() else {
            isCloudAvailable = false
            return
        }
        isCloudAvailable = true
        do {
            let sealed: [Data] = try await CloudSync.shared.fetchWaveScanParts(macID: credentials.macID)
            // Parts of an older pairing (another key) cannot be opened: left aside.
            let parts: [WaveScanPart] = sealed.compactMap {
                try? WaveScanPart(sealed: $0, key: credentials.key, macID: credentials.macID)
            }
            scans = WaveScan.merging(parts)
            hasLoaded = true
        } catch {
            logger.error("Waves not read: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Deletes a measurement, here and in iCloud.
    public func delete(_ scan: WaveScan) async {
        scans.removeAll { $0.id == scan.id }
        guard !isDemo else { return }
        do {
            try await CloudSync.shared.deleteWaveScan(id: scan.id)
        } catch {
            logger.error("Waves not deleted: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Forgets everything (unpaired).
    public func clear() {
        cancel()
        scans = []
        hasLoaded = false
        phase = .idle
    }

    /// Shows sample measurements (demo mode).
    public func showDemo(_ scans: [WaveScan], phase: WaveScanPhase = .idle) {
        isDemo = true
        self.scans = scans
        self.phase = phase
        isCloudAvailable = true
        hasLoaded = true
    }

    // MARK: - Measuring

    /// Starts a measurement here and on the other device. `false` when the other device could not
    /// be told (out of reach).
    @discardableResult
    public func start(name: String) -> Bool {
        guard phase.run == nil else { return false }
        let trimmed: String = .init(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(WaveScan.maximumNameLength))
        let run: WaveScanRun = .init(id: .init(), name: trimmed, date: .now, startedAt: .now, isStartedHere: true)
        guard sendSignal(.start(id: run.id, name: run.name, date: run.date)) else { return false }
        measure(run)
        return true
    }

    /// Stops the measurement under way, here and on the other device: nothing is kept.
    public func cancel() {
        guard let run = phase.run else { return }
        task?.cancel()
        task = nil
        _ = sendSignal(.cancelled(id: run.id))
        lastMeasurementEnd = .now
        phase = .idle
    }

    /// Back to the list after a finished or failed measurement.
    public func acknowledge() {
        guard phase.run == nil else { return }
        phase = .idle
    }

    /// A signal from the other device.
    public func receive(_ signal: WaveScanSignal) {
        switch signal {
        case let .start(id, name, date):
            guard phase.run == nil, canTakePart() else {
                _ = sendSignal(.declined(id: id))
                return
            }
            let run: WaveScanRun = .init(id: id, name: name, date: date, startedAt: .now, isStartedHere: false)
            onRemoteStart?(run)
            measure(run)
        case let .saved(id):
            savedByPeer.insert(id)
            // Saved after this device was done waiting: the list gets it anyway.
            if phase.run?.id != id {
                Task { await refresh() }
            }
        case let .declined(id):
            declinedByPeer.insert(id)
            if phase.run?.id == id {
                isPeerMissing = true
            }
        case let .cancelled(id):
            // Stopped on the other device: stopped here too, without a word back.
            guard phase.run?.id == id else { return }
            task?.cancel()
            task = nil
            lastMeasurementEnd = .now
            phase = .idle
        }
    }

    private func measure(_ run: WaveScanRun) {
        isPeerMissing = declinedByPeer.contains(run.id)
        phase = .measuring(run)
        logger.notice("Measuring the waves (\(run.isStartedHere ? "started here" : "started on the other device", privacy: .public))")
        task = Task { [weak self] in
            guard let self, let captureHandler = self.captureHandler else { return }
            let capture: WaveScanPart.Capture = await captureHandler(run)
            self.lastMeasurementEnd = .now
            guard !Task.isCancelled else { return }
            await self.save(.init(scanID: run.id, name: run.name, date: run.date, capture: capture), run: run)
        }
    }

    private func save(_ part: WaveScanPart, run: WaveScanRun) async {
        phase = .saving(run)
        guard let credentials = credentials() else {
            phase = .failed(.notSaved)
            return
        }
        guard await CloudSync.shared.isAvailable() else {
            isCloudAvailable = false
            phase = .failed(.iCloudUnavailable)
            return
        }
        // Shown right away, whatever iCloud takes.
        insert(part)
        do {
            let sealed: Data = try part.sealed(key: credentials.key, macID: credentials.macID)
            try await CloudSync.shared.saveWaveScanPart(sealed, scanID: run.id, side: side, macID: credentials.macID)
        } catch {
            logger.error("Waves not saved: \(error.localizedDescription, privacy: .public)")
            phase = .failed(.notSaved)
            return
        }
        _ = sendSignal(.saved(id: run.id))
        await waitForPeer(run)
        guard !Task.isCancelled else { return }
        phase = .finished(id: run.id)
    }

    /// Waits a little for the part of the other device, then reads both.
    private func waitForPeer(_ run: WaveScanRun) async {
        let deadline: ContinuousClock.Instant = .now + Self.peerWait
        while !savedByPeer.contains(run.id), !declinedByPeer.contains(run.id), ContinuousClock.now < deadline, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(500))
        }
        if !savedByPeer.contains(run.id) {
            isPeerMissing = true
        }
        await refresh()
        // iCloud may lag behind what this device just saved.
        if let local = localParts[run.id] {
            insert(local)
        }
    }

    @ObservationIgnored private var localParts: [UUID: WaveScanPart] = [:]

    private func insert(_ part: WaveScanPart) {
        localParts[part.scanID] = part
        if let index = scans.firstIndex(where: { $0.id == part.scanID }) {
            scans[index].apply(part)
        } else {
            var scan: WaveScan = .init(id: part.scanID, name: part.name, date: part.date)
            scan.apply(part)
            scans.insert(scan, at: 0)
            scans.sort { $0.date > $1.date }
        }
    }
}
