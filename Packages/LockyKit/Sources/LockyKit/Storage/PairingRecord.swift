import CryptoKit
import Foundation

/// Non secret description of a pairing, persisted in user defaults on both devices.
///
/// The pairing key itself lives in the keychain, see ``PairingVault``.
public struct PairingRecord: Codable, Sendable, Equatable {
    /// Identifier of the pairing, advertised as the iPhone service UUID.
    public var pairingID: UUID
    /// Identifier of the other device.
    public var peerID: UUID
    /// Name of the other device.
    public var peerName: String
    /// RSSI measured at ``calibrationDistance``.
    public var calibrationRSSI: Double?
    /// Distance of the iPhone during the calibration, in meters; `nil` for the calibrations of the
    /// first versions, measured against the Mac (``DistanceModel/legacyCalibrationDistance``).
    public var calibrationDistance: Double?
    /// RSSI measured at ``DistanceModel/farCalibrationDistance``, `nil` for one point calibrations.
    public var farCalibrationRSSI: Double?
    public var pairedAt: Date

    public init(
        pairingID: UUID,
        peerID: UUID,
        peerName: String,
        calibrationRSSI: Double?,
        calibrationDistance: Double? = DistanceModel.calibrationDistance,
        pairedAt: Date
    ) {
        self.pairingID = pairingID
        self.peerID = peerID
        self.peerName = peerName
        self.calibrationRSSI = calibrationRSSI
        self.calibrationDistance = calibrationDistance
        self.pairedAt = pairedAt
    }

    /// Distance model of this pairing, `nil` before the calibration.
    public var distanceModel: DistanceModel? {
        guard let calibrationRSSI else { return nil }
        let distance: Double = calibrationDistance ?? DistanceModel.legacyCalibrationDistance
        guard let farCalibrationRSSI else {
            return DistanceModel(calibrationRSSI: calibrationRSSI, calibrationDistance: distance)
        }
        return DistanceModel(
            nearRSSI: calibrationRSSI,
            nearDistance: distance,
            farRSSI: farCalibrationRSSI,
            farDistance: DistanceModel.farCalibrationDistance
        )
    }

    /// Records a new calibration, measured at 1 m and 2 m.
    public mutating func calibrate(near: Double, far: Double?) {
        calibrationRSSI = near
        calibrationDistance = CalibrationStep.near.distance
        farCalibrationRSSI = far
    }
}
