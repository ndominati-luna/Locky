import CloudKit
import Foundation
import OSLog

/// iCloud synchronization between the Mac and the iPhone, in the user's private database.
///
/// This replaces the former Parse server:
/// - the Mac publishes its name, model, lock state and images (`MacStatus` record), then tells the
///   iPhone over Bluetooth to fetch new images right away (``LockyMessage/macImagesUpdated(version:)``);
/// - the Mac uploads intrusion photos (`Intrusion` records);
/// - the iPhone subscribes to both: intrusions trigger a visible push, Mac changes a silent one
///   (for when the iPhone is away from the Mac);
/// - the iPhone drops the settings of the Mac chosen out of reach (`MacSettings` record, sealed
///   with the pairing key, see ``MacSettingsEnvelope``); the Mac subscribes to them (silent push)
///   and reads them while the iPhone is away.
///
/// Everything lives in a custom zone and is read with zone change fetches, so no query index has
/// to be configured in the CloudKit console.
public actor CloudSync {
    /// Shared instance.
    public static let shared: CloudSync = .init()
    /// CloudKit container shared by the Mac and iOS apps.
    public static let containerIdentifier: String = "iCloud.studio.lunabee.locky"

    private enum RecordType {
        static let macStatus: String = "MacStatus"
        static let intrusion: String = "Intrusion"
        static let nowPlaying: String = "NowPlaying"
        static let macSettings: String = "MacSettings"
    }

    private enum SubscriptionID {
        static let intrusions: String = "locky-intrusions"
        static let macStatus: String = "locky-mac-status"
        static let macSettings: String = "locky-mac-settings"
    }

    /// Number of intrusion reports kept in iCloud.
    public static let maximumIntrusionCount: Int = 50

    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "CloudSync")
    private let zoneID: CKRecordZone.ID = .init(zoneName: "Locky", ownerName: CKCurrentUserDefaultName)
    private var container: CKContainer?
    private var isZoneReady: Bool = false

    private init() {}

    /// Lazily created: instantiating a container without the iCloud entitlement raises an exception,
    /// so nothing touches CloudKit until a sync is actually requested.
    private var database: CKDatabase {
        if let container { return container.privateCloudDatabase }
        let container: CKContainer = .init(identifier: Self.containerIdentifier)
        self.container = container
        return container.privateCloudDatabase
    }

    // MARK: - Account

    /// `true` when an iCloud account is available.
    public func isAvailable() async -> Bool {
        guard CloudKitEntitlement.isPresent else { return false }
        do {
            _ = database
            return try await container?.accountStatus() == .available
        } catch {
            logger.error("iCloud account status failed: \(error.localizedDescription)")
            return false
        }
    }

    private func prepareZone() async throws {
        guard !isZoneReady else { return }
        guard await isAvailable() else { throw CloudSyncError.accountUnavailable }
        _ = try await database.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        isZoneReady = true
    }

    // MARK: - Mac status

    /// Mac side: publishes the Mac information. The images are only uploaded when their version
    /// changed, so status updates stay tiny.
    /// - Parameter imagesAreNew: The caller knows the images changed since its last publication (a
    ///   new wallpaper): they are uploaded without reading the record first, one round trip less.
    public func publish(_ macRecord: CloudMacRecord, imagesAreNew: Bool = false) async throws {
        try await prepareZone()
        let recordID: CKRecord.ID = .init(recordName: "mac-\(macRecord.status.macID.uuidString)", zoneID: zoneID)
        // Saved with `.changedKeys`: a new record object only updates the fields set below.
        let record: CKRecord = imagesAreNew
            ? .init(recordType: RecordType.macStatus, recordID: recordID)
            : try await existingRecord(recordID, keys: ["imagesVersion"]) ?? .init(recordType: RecordType.macStatus, recordID: recordID)
        let status: MacStatus = macRecord.status
        record["macID"] = status.macID.uuidString
        record["name"] = status.name
        record["model"] = status.model
        record["productName"] = status.productName
        record["family"] = status.family.rawValue
        record["systemVersion"] = status.systemVersion
        record["userName"] = status.userName
        record["lockState"] = status.lockState.rawValue
        record["lockStateDate"] = status.lockStateDate
        record["isAutoLockEnabled"] = status.isAutoLockEnabled ? 1 : 0
        record["unlockCount"] = status.unlockCount
        record["cameraAccess"] = status.cameraAccess?.rawValue
        record["deviceType"] = status.deviceType
        var temporaryFiles: [URL] = []
        defer { temporaryFiles.forEach { try? FileManager.default.removeItem(at: $0) } }
        if let imagesVersion = macRecord.imagesVersion, record["imagesVersion"] as? String != imagesVersion {
            record["imagesVersion"] = imagesVersion
            // The image of the Mac is embedded in the iPhone now: drop the one older versions sent.
            record["deviceScreen"] = nil
            record["deviceImage"] = nil
            let assets: [(key: String, data: Data?)] = [
                ("wallpaper", macRecord.wallpaper),
                ("userPicture", macRecord.userPicture),
                ("phoneImage", macRecord.phoneImage)
            ]
            for asset in assets {
                guard let data = asset.data else {
                    record[asset.key] = nil
                    continue
                }
                let url: URL = try Self.temporaryFile(data)
                temporaryFiles.append(url)
                record[asset.key] = CKAsset(fileURL: url)
            }
        }
        try await modify(saving: [record], savePolicy: .changedKeys)
    }

    /// Mac side: only updates the lock state (cheap, called on every lock and unlock).
    public func publishLockState(macID: UUID, lockState: LockState, date: Date) async throws {
        try await prepareZone()
        let recordID: CKRecord.ID = .init(recordName: "mac-\(macID.uuidString)", zoneID: zoneID)
        guard let record = try await existingRecord(recordID, keys: ["lockState"]) else { throw CKError(.unknownItem) }
        record["lockState"] = lockState.rawValue
        record["lockStateDate"] = date
        try await modify(saving: [record], savePolicy: .changedKeys)
    }

    /// Saves and deletes records. CloudKit reports a refused record (a field missing from the
    /// production schema, for example) in its results without throwing: rethrown here. Deleting a
    /// record already gone is not an error.
    private func modify(
        saving records: [CKRecord],
        deleting recordIDs: [CKRecord.ID] = [],
        savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged
    ) async throws {
        let results: (
            saveResults: [CKRecord.ID: Result<CKRecord, any Error>],
            deleteResults: [CKRecord.ID: Result<Void, any Error>]
        ) = try await database.modifyRecords(saving: records, deleting: recordIDs, savePolicy: savePolicy)
        for case let .failure(error) in results.saveResults.values {
            throw error
        }
        for case let .failure(error) in results.deleteResults.values where (error as? CKError)?.code != .unknownItem {
            throw error
        }
    }

    /// The record with only `keys`, without downloading its images: enough to update it with the
    /// `.changedKeys` policy. `nil` when it does not exist yet.
    private func existingRecord(_ recordID: CKRecord.ID, keys: [CKRecord.FieldKey]) async throws -> CKRecord? {
        let results: [CKRecord.ID: Result<CKRecord, any Error>] = try await database.records(for: [recordID], desiredKeys: keys)
        switch results[recordID] {
        case let .success(record)?:
            return record
        case let .failure(error as CKError)? where error.code == .unknownItem:
            return nil
        case let .failure(error)?:
            throw error
        case nil:
            return nil
        }
    }

    // MARK: - Now playing

    /// Mac side: the artwork of what the Mac plays, once per artwork (the track itself goes over
    /// Bluetooth, see ``LockyMessage/nowPlaying(_:)``). One record per Mac.
    public func publishNowPlayingArtwork(macID: UUID, artworkID: String, image: Data) async throws {
        try await prepareZone()
        let recordID: CKRecord.ID = .init(recordName: "nowplaying-\(macID.uuidString)", zoneID: zoneID)
        // A new record object saved with `.changedKeys` only updates these fields: no read first.
        let record: CKRecord = .init(recordType: RecordType.nowPlaying, recordID: recordID)
        record["artworkID"] = artworkID
        let url: URL = try Self.temporaryFile(image)
        defer { try? FileManager.default.removeItem(at: url) }
        record["image"] = CKAsset(fileURL: url)
        try await modify(saving: [record], savePolicy: .changedKeys)
    }

    /// iPhone side: the artwork `artworkID` of what the Mac plays, `nil` when another one already
    /// replaced it.
    public func fetchNowPlayingArtwork(macID: UUID, artworkID: String) async throws -> Data? {
        try await prepareZone()
        let recordID: CKRecord.ID = .init(recordName: "nowplaying-\(macID.uuidString)", zoneID: zoneID)
        guard
            let record = try await existingRecord(recordID, keys: ["artworkID", "image"]),
            record["artworkID"] as? String == artworkID
        else { return nil }
        return Self.assetData(record["image"])
    }

    /// Mac side: forgets what was playing (Locky quits, or starts after being killed).
    public func clearNowPlaying(macID: UUID) async throws {
        guard await isAvailable() else { return }
        try await prepareZone()
        let recordID: CKRecord.ID = .init(recordName: "nowplaying-\(macID.uuidString)", zoneID: zoneID)
        try await modify(saving: [], deleting: [recordID])
    }

    /// iPhone side, with a Mac still on Locky 1.0.0: what the Mac is playing. The artwork is only
    /// downloaded when it is not `knownArtworkID`; `nil` when the Mac published nothing.
    public func fetchNowPlaying(macID: UUID, knownArtworkID: String?) async throws -> CloudNowPlaying? {
        try await prepareZone()
        let recordID: CKRecord.ID = .init(recordName: "nowplaying-\(macID.uuidString)", zoneID: zoneID)
        guard let record = try await existingRecord(recordID, keys: ["revision", "track", "artworkID"]) else { return nil }
        var playing: NowPlaying?
        if let track = record["track"] as? String {
            do {
                playing = try JSONDecoder().decode(NowPlaying.self, from: Data(track.utf8))
            } catch {
                logger.error("Undecodable now playing: \(String(describing: error), privacy: .public)")
            }
        }
        let artworkID: String? = record["artworkID"] as? String
        var artwork: Data?
        if let artworkID, artworkID != knownArtworkID {
            artwork = try await existingRecord(recordID, keys: ["image"]).flatMap { Self.assetData($0["image"]) }
        }
        return .init(revision: record["revision"] as? String ?? "", playing: playing, artworkID: artworkID, artwork: artwork)
    }

    // MARK: - Settings of the Mac

    /// iPhone side: the settings of the Mac chosen out of reach, sealed (see
    /// ``MacSettingsEnvelope/sealed(key:macID:)``). One record per Mac, replaced each time.
    public func publishMacSettings(_ sealed: Data, macID: UUID) async throws {
        try await prepareZone()
        // A new record object saved with `.changedKeys` only updates this field: no read first.
        let record: CKRecord = .init(recordType: RecordType.macSettings, recordID: macSettingsID(macID))
        record["sealed"] = sealed
        try await modify(saving: [record], savePolicy: .changedKeys)
    }

    /// Mac side: the sealed settings the iPhone left, `nil` when it never left any.
    public func fetchMacSettings(macID: UUID) async throws -> Data? {
        try await prepareZone()
        return try await existingRecord(macSettingsID(macID), keys: ["sealed"])?["sealed"] as? Data
    }

    private func macSettingsID(_ macID: UUID) -> CKRecord.ID {
        .init(recordName: "settings-\(macID.uuidString)", zoneID: zoneID)
    }

    // MARK: - Intrusions

    /// Mac side: uploads an intrusion photo. The iPhone gets a push notification.
    public func uploadIntrusion(macID: UUID, macName: String, date: Date, photo: Data?) async throws {
        try await prepareZone()
        let record: CKRecord = .init(
            recordType: RecordType.intrusion,
            recordID: .init(recordName: "intrusion-\(UUID().uuidString)", zoneID: zoneID)
        )
        record["macID"] = macID.uuidString
        record["macName"] = macName
        record["date"] = date
        var temporaryFile: URL?
        if let photo {
            let url: URL = try Self.temporaryFile(photo)
            temporaryFile = url
            record["photo"] = CKAsset(fileURL: url)
        }
        defer { temporaryFile.map { try? FileManager.default.removeItem(at: $0) } }
        try await modify(saving: [record])
        try await pruneIntrusions(macID: macID)
    }

    /// Deletes intrusion reports.
    public func deleteIntrusions(ids: [String]) async throws {
        guard !ids.isEmpty else { return }
        try await prepareZone()
        let recordIDs: [CKRecord.ID] = ids.map { .init(recordName: $0, zoneID: zoneID) }
        try await modify(saving: [], deleting: recordIDs)
    }

    private func pruneIntrusions(macID: UUID) async throws {
        let reports: [IntrusionReport] = try await fetchAll().intrusions.filter { $0.macID == macID }
        let obsolete: [String] = reports.dropFirst(Self.maximumIntrusionCount).map(\.id)
        try await deleteIntrusions(ids: obsolete)
    }

    // MARK: - Fetch

    /// Fetches the whole Locky zone: Mac records and intrusion reports (newest first).
    public func fetchAll() async throws -> (macs: [CloudMacRecord], intrusions: [IntrusionReport]) {
        try await prepareZone()
        var macs: [CloudMacRecord] = []
        var intrusions: [IntrusionReport] = []
        var token: CKServerChangeToken?
        var moreComing: Bool = true
        while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token)
            for (_, result) in changes.modificationResultsByID {
                guard let record = try? result.get().record else { continue }
                switch record.recordType {
                case RecordType.macStatus:
                    if let mac = Self.macRecord(from: record) { macs.append(mac) }
                case RecordType.intrusion:
                    if let intrusion = Self.intrusion(from: record) { intrusions.append(intrusion) }
                default:
                    break
                }
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        return (macs, intrusions.sorted { $0.date > $1.date })
    }

    /// iPhone side: fetches the record of a given Mac.
    /// - Parameter knownImagesVersion: ``MacImages/version`` already on the device: the images are
    ///   only downloaded when they changed (otherwise they are `nil` in the result).
    /// - Parameter imagesAreNew: The caller knows newer images are there (the Mac said so over
    ///   Bluetooth): everything is fetched at once instead of the status first.
    public func fetchMac(macID: UUID, knownImagesVersion: String? = nil, imagesAreNew: Bool = false) async throws -> CloudMacRecord? {
        try await prepareZone()
        let recordID: CKRecord.ID = .init(recordName: "mac-\(macID.uuidString)", zoneID: zoneID)
        if imagesAreNew {
            return try await existingRecord(recordID, keys: Self.statusKeys + Self.imageKeys).flatMap(Self.macRecord(from:))
        }
        guard let status = try await existingRecord(recordID, keys: Self.statusKeys) else { return nil }
        guard let version = status["imagesVersion"] as? String, version != knownImagesVersion else {
            return Self.macRecord(from: status)
        }
        guard let full = try await existingRecord(recordID, keys: Self.statusKeys + Self.imageKeys) else { return nil }
        return Self.macRecord(from: full)
    }

    /// Apple Watch side: the Mac updated last, found without downloading any image first (the Watch
    /// does not need the iPhone to know which Mac is paired).
    public func fetchLatestMac(knownImagesVersion: String?) async throws -> CloudMacRecord? {
        try await prepareZone()
        var latest: (macID: UUID, date: Date)?
        var token: CKServerChangeToken?
        var moreComing: Bool = true
        while moreComing {
            let changes = try await database.recordZoneChanges(inZoneWith: zoneID, since: token, desiredKeys: ["macID"])
            for (_, result) in changes.modificationResultsByID {
                guard
                    let record = try? result.get().record,
                    record.recordType == RecordType.macStatus,
                    let macID = (record["macID"] as? String).flatMap(UUID.init(uuidString:))
                else { continue }
                let date: Date = record.modificationDate ?? .distantPast
                if date > latest?.date ?? .distantPast {
                    latest = (macID, date)
                }
            }
            token = changes.changeToken
            moreComing = changes.moreComing
        }
        guard let latest else { return nil }
        return try await fetchMac(macID: latest.macID, knownImagesVersion: knownImagesVersion)
    }

    /// Every field of a `MacStatus` record but its images.
    private static let statusKeys: [CKRecord.FieldKey] = [
        "macID", "name", "model", "productName", "family", "systemVersion", "userName", "lockState",
        "lockStateDate", "isAutoLockEnabled", "unlockCount", "cameraAccess", "imagesVersion", "deviceType"
    ]

    /// The images of a `MacStatus` record.
    private static let imageKeys: [CKRecord.FieldKey] = ["wallpaper", "userPicture", "phoneImage"]

    // MARK: - Subscriptions

    /// iPhone side: registers the push subscriptions (idempotent): a silent push whenever the Mac
    /// publishes its state (wallpaper, name, lock state…), and an alert for every intrusion.
    /// - Parameter intrusionAlertKey: Localization key of the intrusion alert in the app strings, or
    ///   `nil` without intrusion detection (no alert subscription then).
    public func registerSubscriptions(intrusionAlertKey: String?) async throws {
        try await prepareZone()
        let statusInfo: CKSubscription.NotificationInfo = .init()
        statusInfo.shouldSendContentAvailable = true
        let status: CKQuerySubscription = .init(
            recordType: RecordType.macStatus,
            predicate: .init(value: true),
            subscriptionID: SubscriptionID.macStatus,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        status.zoneID = zoneID
        status.notificationInfo = statusInfo
        var subscriptions: [CKSubscription] = [status]

        if let intrusionAlertKey {
            let intrusionInfo: CKSubscription.NotificationInfo = .init()
            intrusionInfo.alertLocalizationKey = intrusionAlertKey
            intrusionInfo.soundName = "default"
            intrusionInfo.shouldBadge = true
            intrusionInfo.desiredKeys = ["macName", "date"]
            intrusionInfo.category = "INTRUSION"
            let intrusions: CKQuerySubscription = .init(
                recordType: RecordType.intrusion,
                predicate: .init(value: true),
                subscriptionID: SubscriptionID.intrusions,
                options: [.firesOnRecordCreation]
            )
            intrusions.zoneID = zoneID
            intrusions.notificationInfo = intrusionInfo
            subscriptions.append(intrusions)
        }

        _ = try await database.modifySubscriptions(saving: subscriptions, deleting: [])
    }

    /// Mac side: a silent push whenever the iPhone leaves settings for a Mac (idempotent). It fails
    /// while the `MacSettings` record type does not exist yet (no iPhone ever left any).
    public func registerMacSettingsSubscription() async throws {
        try await prepareZone()
        let info: CKSubscription.NotificationInfo = .init()
        info.shouldSendContentAvailable = true
        let subscription: CKQuerySubscription = .init(
            recordType: RecordType.macSettings,
            predicate: .init(value: true),
            subscriptionID: SubscriptionID.macSettings,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate]
        )
        subscription.zoneID = zoneID
        subscription.notificationInfo = info
        _ = try await database.modifySubscriptions(saving: [subscription], deleting: [])
    }

    /// `true` for the push of ``registerMacSettingsSubscription()``. Subscriptions belong to the
    /// iCloud account, not to a device: every Locky of the account gets the pushes of all of them,
    /// and only the Mac cares about this one.
    public nonisolated static func isMacSettingsNotification(_ userInfo: [AnyHashable: Any]) -> Bool {
        CKNotification(fromRemoteNotificationDictionary: userInfo)?.subscriptionID == SubscriptionID.macSettings
    }

    // MARK: - Mapping

    private static func macRecord(from record: CKRecord) -> CloudMacRecord? {
        guard
            let macIDString = record["macID"] as? String,
            let macID = UUID(uuidString: macIDString)
        else { return nil }
        let status: MacStatus = .init(
            macID: macID,
            name: record["name"] as? String ?? "Mac",
            model: record["model"] as? String ?? "",
            productName: record["productName"] as? String ?? "Mac",
            family: (record["family"] as? String).flatMap(MacFamily.init(rawValue:)) ?? .unknown,
            systemVersion: record["systemVersion"] as? String ?? "",
            userName: record["userName"] as? String ?? "",
            lockState: (record["lockState"] as? String).flatMap(LockState.init(rawValue:)) ?? .unknown,
            lockStateDate: record["lockStateDate"] as? Date ?? .distantPast,
            isAutoLockEnabled: (record["isAutoLockEnabled"] as? Int ?? 1) != 0,
            unlockCount: record["unlockCount"] as? Int ?? 0,
            cameraAccess: (record["cameraAccess"] as? String).flatMap(CameraAccess.init(rawValue:)),
            deviceType: record["deviceType"] as? String
        )
        // An image present in iCloud but unreadable (protected file, iPhone locked) makes the
        // record incomplete.
        var isComplete: Bool = true
        func image(_ key: CKRecord.FieldKey) -> Data? {
            guard record[key] is CKAsset else { return nil }
            let data: Data? = assetData(record[key])
            if data == nil {
                isComplete = false
            }
            return data
        }
        return .init(
            status: status,
            imagesVersion: record["imagesVersion"] as? String,
            wallpaper: image("wallpaper"),
            userPicture: image("userPicture"),
            phoneImage: image("phoneImage"),
            modifiedAt: record.modificationDate,
            isComplete: isComplete
        )
    }

    private static func intrusion(from record: CKRecord) -> IntrusionReport? {
        guard
            let macIDString = record["macID"] as? String,
            let macID = UUID(uuidString: macIDString)
        else { return nil }
        return .init(
            id: record.recordID.recordName,
            macID: macID,
            macName: record["macName"] as? String ?? "Mac",
            date: record["date"] as? Date ?? record.creationDate ?? .now,
            photo: assetData(record["photo"])
        )
    }

    private static func assetData(_ value: (any CKRecordValueProtocol)?) -> Data? {
        guard let asset = value as? CKAsset, let url = asset.fileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func temporaryFile(_ data: Data) throws -> URL {
        let url: URL = .temporaryDirectory.appending(path: "locky-\(UUID().uuidString).asset")
        try data.write(to: url, options: .atomic)
        return url
    }
}
