import Foundation

/// Every message exchanged between the iPhone and the Mac.
///
/// Only the handshake messages (pairing request, response, key reveal, session hello) travel in
/// clear text: ``WireCodec`` rejects any other message that is not encrypted with the session key.
public enum LockyMessage: Codable, Sendable, Equatable {
    // MARK: - Clear text handshake
    /// Mac → iPhone: starts a pairing.
    case pairingRequest(PairingRequest)
    /// iPhone → Mac: answers a pairing request with the iPhone key.
    case pairingResponse(PairingResponse)
    /// Mac → iPhone: reveals the Mac key committed in the pairing request.
    case pairingKeyReveal(PairingKeyReveal)
    /// Both directions: opens a session between paired devices.
    case sessionHello(SessionHello)

    // MARK: - Pairing (encrypted)
    /// iPhone → Mac: the user confirmed the verification code.
    case pairingConfirmed(PairingConfirmation)
    /// Mac → iPhone: the verified macOS session password, to be stored in the iPhone keychain.
    case storePassword(String)
    /// iPhone → Mac: the password has been stored.
    case passwordStored
    /// Mac → iPhone: RSSI measured with the iPhone at the distance of `step` (pairing or settings).
    case calibration(CalibrationStep, rssi: Double)
    /// iPhone → Mac: motion calibration is over, Locky is ready.
    case calibrationFinished(PhonePreferences)
    /// Both directions: progress of the setup that follows the pairing (guided first try).
    case setupProgress(SetupProgress)

    // MARK: - Status (encrypted)
    /// Heartbeat.
    case ping
    /// iPhone → Mac.
    case deviceStatus(DeviceStatus)
    /// iPhone → Mac.
    case preferences(PhonePreferences)
    /// iPhone → Mac.
    case battery(level: Int)
    /// iPhone → Mac: the iPhone started or stopped moving.
    case motion(isMoving: Bool)
    /// iPhone → Mac: a phone call started or ended (the Mac locks less eagerly during calls).
    case call(isActive: Bool)
    /// Mac → iPhone.
    case macStatus(MacStatus)
    /// Mac → iPhone: new images of the Mac are in iCloud, fetch them now. Images never travel over
    /// Bluetooth: a transfer would hold the link for seconds and starve the heartbeats.
    case macImagesUpdated(version: String)
    /// Mac → iPhone.
    case lockState(LockState)
    /// Both ways: automatic locking paused or resumed from the menu bar of the Mac, or from the
    /// settings of the iPhone (the Mac applies it and sends it back).
    case autoLock(isEnabled: Bool)
    /// Mac → iPhone: filtered signal and estimated distance, for the distance gauge.
    case proximity(ProximityReading)

    // MARK: - Dashboard (encrypted)
    /// iPhone → Mac: the dashboard is on screen (unfolded iPhone Duo), stream the Mac state.
    case dashboard(isVisible: Bool)
    /// Mac → iPhone: processor, memory, disk, battery, volume.
    case macMetrics(MacMetrics)
    /// Mac (Locky 1.0.0) → iPhone: what the Mac is playing changed, it is in iCloud
    /// (``CloudSync/fetchNowPlaying(macID:knownArtworkID:)``). Newer Macs send ``nowPlaying(_:)``.
    case nowPlayingChanged(revision: String)
    /// Mac → iPhone: what the Mac is playing (`nil`: nothing), right when it changes. A few hundred
    /// bytes: the artwork stays in iCloud
    /// (``CloudSync/fetchNowPlayingArtwork(macID:artworkID:)``), named by its identifier once
    /// uploaded.
    case nowPlaying(NowPlaying?)
    /// iPhone → Mac: playback and volume.
    case mediaCommand(MediaCommand)

    // MARK: - Commands (encrypted)
    /// iPhone → Mac.
    case lock(origin: CommandOrigin)
    /// iPhone → Mac.
    case unlock(password: String, origin: CommandOrigin)
    /// Mac → iPhone: the Mac needs the session password to unlock.
    case passwordRequest(PasswordRequestReason)
    /// Mac → iPhone: the typed password did not unlock the session (it probably changed).
    case unlockFailed
    /// Both directions: forget the pairing.
    case unpair
    /// iPhone → Mac: the iPhone app is being terminated, the disconnection is expected.
    case appWillTerminate
    /// iPhone → Mac: the iPhone lies at the distance of `step`, measure the signal (pairing, or
    /// again from the settings). The Mac answers with ``calibration(_:rssi:)``.
    case calibrationRequest(CalibrationStep)
    /// iPhone → Mac: let Locky use the camera of the Mac (intruder detection). The Mac asks macOS
    /// if it never did, or opens the Camera pane of its Privacy settings.
    case cameraAccessRequest
    /// Both ways, between peers announcing ``LockyFeature/lockAnimation``: the lock animation of
    /// the Mac, sent by the Mac once it knows the iPhone and whenever it changes; changed on the
    /// iPhone, the Mac applies it and sends it back.
    case lockAnimation(LockAnimationSettings)
    /// iPhone → Mac (``LockyFeature/lockAnimation``): play the lock animation without locking.
    case previewLockAnimation
    /// iPhone → Mac (``LockyFeature/macUpdates``): look for a new version of Locky for Mac and show
    /// the update window of Sparkle on the Mac.
    case checkForUpdates

    /// `true` for messages allowed without encryption.
    public var isHandshake: Bool {
        switch self {
        case .pairingRequest, .pairingResponse, .pairingKeyReveal, .sessionHello: true
        default: false
        }
    }
}
