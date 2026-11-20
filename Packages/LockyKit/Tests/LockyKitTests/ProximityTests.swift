import Foundation
import Testing
@testable import LockyKit

struct ProximityTests {
    private let model: DistanceModel = .init(calibrationRSSI: -45)
    private let walkingAway: ProximityContext = .init(isLocked: false, isMoving: true, isComputerInUse: false, isOnCall: false)

    @Test
    func stillPhoneResistsSignalDrops() throws {
        var filter: RSSIFilter = .init()
        let start: Date = .now
        for second in 0..<5 {
            filter.add(-50, isMoving: false, at: start.addingTimeInterval(Double(second)))
        }
        filter.add(-80, isMoving: false, at: start.addingTimeInterval(5))
        let estimate: Double = try #require(filter.estimate)
        #expect(estimate > -53)
    }

    @Test
    func movingPhoneFollowsTheSignal() throws {
        var filter: RSSIFilter = .init()
        let start: Date = .now
        filter.add(-50, isMoving: true, at: start)
        for second in 1...6 {
            filter.add(-80, isMoving: true, at: start.addingTimeInterval(Double(second)))
        }
        let estimate: Double = try #require(filter.estimate)
        #expect(estimate < -76)
    }

    @Test
    func ignoresInvalidReadings() {
        var filter: RSSIFilter = .init()
        filter.add(127, isMoving: true)
        filter.add(0, isMoving: true)
        #expect(filter.estimate == nil)
    }

    @Test
    func pairingRecordsKeepTheirCalibrationDistance() throws {
        var record: PairingRecord = .init(pairingID: .init(), peerID: .init(), peerName: "Mac", calibrationRSSI: -45, pairedAt: .now)
        record.calibrationDistance = nil
        // Saved by a first version: no calibration distance, measured against the Mac.
        let legacy: PairingRecord = try JSONDecoder().decode(PairingRecord.self, from: JSONEncoder().encode(record))
        let legacyModel: DistanceModel = try #require(legacy.distanceModel)
        #expect(abs(legacyModel.distance(forRSSI: -45) - DistanceModel.legacyCalibrationDistance) < 0.0001)
        record.calibrate(near: -67, far: nil)
        let model: DistanceModel = try #require(record.distanceModel)
        #expect(abs(model.distance(forRSSI: -67) - 1) < 0.0001)
    }

    @Test
    func twoPointCalibrationMeasuresTheRoom() throws {
        var record: PairingRecord = .init(pairingID: .init(), peerID: .init(), peerName: "Mac", calibrationRSSI: nil, pairedAt: .now)
        // A cluttered room: the signal drops faster than the default exponent says.
        record.calibrate(near: -65, far: -74)
        let model: DistanceModel = try #require(record.distanceModel)
        #expect(abs(model.pathLossExponent - 9 / (10 * log10(2))) < 0.0001)
        #expect(abs(model.distance(forRSSI: -65) - 1) < 0.0001)
        #expect(abs(model.distance(forRSSI: -74) - 2) < 0.0001)
        // Disturbed measure (barely any drop): the default exponent from the 1 m point.
        record.calibrate(near: -65, far: -66)
        let fallback: DistanceModel = try #require(record.distanceModel)
        #expect(fallback.pathLossExponent == DistanceModel.defaultPathLossExponent)
        #expect(abs(fallback.distance(forRSSI: -65) - 1) < 0.0001)
    }

    @Test
    func distanceModelRoundTrips() {
        #expect(abs(model.distance(forRSSI: -45) - DistanceModel.calibrationDistance) < 0.0001)
        #expect(abs(model.distance(forRSSI: model.rssi(atDistance: 3)) - 3) < 0.0001)
        #expect(model.distance(forRSSI: -80) > model.distance(forRSSI: -60))
    }

    @Test
    func defaultLockDistanceMatchesTheFormerThreshold() {
        // The former app locked halfway between its calibration against the Mac (-45 dBm) and
        // -95 dBm, at -70 dBm: the default lock distance must stay in the same area, whether the
        // calibration was measured against the Mac (first versions) or at 1 m (about 22 dB lower).
        let legacy: DistanceModel = .init(calibrationRSSI: -45, calibrationDistance: DistanceModel.legacyCalibrationDistance)
        #expect(abs(legacy.rssi(atDistance: DistanceModel.defaultLockDistance) - -70) < 2)
        let atOneMeter: DistanceModel = .init(calibrationRSSI: -67)
        #expect(abs(atOneMeter.rssi(atDistance: DistanceModel.defaultLockDistance) - -70) < 2)
    }

    @Test
    func locksOnlyWhenFarMovingAndIdle() {
        let engine: ProximityEngine = .init(model: model)
        let far: ProximityReading = .init(rssi: -80, distance: 6)
        #expect(engine.evaluate(far, context: walkingAway) == .lock)
        var still: ProximityContext = walkingAway
        still.isMoving = false
        #expect(engine.evaluate(far, context: still) == .stay)
        var inUse: ProximityContext = walkingAway
        inUse.isComputerInUse = true
        #expect(engine.evaluate(far, context: inUse) == .stay)
        #expect(engine.evaluate(.init(rssi: -60, distance: 1), context: walkingAway) == .stay)
    }

    @Test
    func callsDoubleTheLockDistance() {
        let engine: ProximityEngine = .init(model: model, lockDistance: 3)
        var onCall: ProximityContext = walkingAway
        onCall.isOnCall = true
        #expect(engine.evaluate(.init(rssi: -75, distance: 5), context: onCall) == .stay)
        #expect(engine.evaluate(.init(rssi: -85, distance: 7), context: onCall) == .lock)
    }

    @Test
    func unlocksWithHysteresis() {
        let engine: ProximityEngine = .init(model: model, lockDistance: 3)
        let locked: ProximityContext = .init(isLocked: true, isMoving: false, isComputerInUse: false, isOnCall: false)
        #expect(engine.evaluate(.init(rssi: -69, distance: 2.8), context: locked) == .stay)
        #expect(engine.evaluate(.init(rssi: -60, distance: 1.5), context: locked) == .unlock)
    }

    @Test
    func decisionsNeedADwellTime() {
        var engine: ProximityEngine = .init(model: model, lockDistance: 3)
        let start: Date = .now
        var decisions: [ProximityDecision] = []
        for step in 0..<40 {
            let date: Date = start.addingTimeInterval(Double(step) * 0.25)
            decisions.append(engine.ingest(rssi: step < 4 ? -50 : -90, at: date, context: walkingAway).decision)
        }
        let firstLock: Int? = decisions.firstIndex(of: .lock)
        #expect(firstLock != nil)
        // Never before the signal had time to drop and stay low for the dwell time.
        #expect((firstLock ?? 0) >= 4 + Int(ProximityEngine.lockDwell / 0.25))
    }

    @Test
    func familyFromProductName() {
        #expect(MacFamily(productName: "MacBook Pro (14-inch, 2021)") == .macBook)
        #expect(MacFamily(productName: "MacBookAir10,1") == .macBook)
        #expect(MacFamily(productName: "iMac (24-inch, 2024)") == .iMac)
        #expect(MacFamily(productName: "Mac mini (2024)") == .macMini)
        #expect(MacFamily(productName: "Mac Studio (2025)") == .macStudio)
        #expect(MacFamily(productName: "Mac Pro (2023)") == .macPro)
        #expect(MacFamily(productName: "Mac16,7") == .unknown)
    }

    @Test
    func motionBaseline() {
        let still: [MotionSample] = [
            .init(acceleration: [0.01, -0.02, 0.005], rotation: [0.01, 0.02, -0.03]),
            .init(acceleration: [-0.015, 0.01, 0.0], rotation: [0.0, -0.01, 0.01])
        ]
        let baseline: MotionBaseline = .measure(still)
        #expect(baseline.acceleration == [0.015, 0.02, 0.005])
        #expect(!baseline.isMovement(.init(acceleration: [0.05, 0, 0], rotation: .zero)))
        #expect(baseline.isMovement(.init(acceleration: [0, 0, 0.2], rotation: .zero)))
        #expect(baseline.isMovement(.init(acceleration: .zero, rotation: [0, -0.3, 0])))
    }
}
