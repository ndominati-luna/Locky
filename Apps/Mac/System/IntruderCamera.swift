import AppKit
import AVFoundation
import LockyKit
import OSLog

/// Takes a photo with the built-in camera (intruder detection).
@MainActor
final class IntruderCamera {
    private let logger: Logger = .init(subsystem: "studio.lunabee.locky", category: "Camera")

    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }

    /// The permission of Locky for the camera, or no camera at all.
    static var access: CameraAccess {
        guard AVCaptureDevice.default(for: .video) != nil else { return .unavailable }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .authorized
        case .notDetermined: return .notDetermined
        default: return .denied
        }
    }

    static func requestAccess() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// Opens System Settings on Privacy & Security › Camera, the only place where a refusal can be
    /// undone (macOS never asks twice).
    static func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    /// Captures one JPEG photo, `nil` when no camera is available or access is denied.
    func takePhoto() async -> Data? {
        guard Self.isAuthorized, let device = AVCaptureDevice.default(for: .video) else { return nil }
        let session: AVCaptureSession = .init()
        session.sessionPreset = .photo
        let output: AVCapturePhotoOutput = .init()
        do {
            let input: AVCaptureDeviceInput = try .init(device: device)
            guard session.canAddInput(input), session.canAddOutput(output) else { return nil }
            session.addInput(input)
            session.addOutput(output)
        } catch {
            logger.error("Camera unavailable: \(error.localizedDescription)")
            return nil
        }
        let runner: SessionRunner = .init(session: session)
        await runner.start()
        // Let the exposure settle, otherwise the first frame is dark.
        try? await Task.sleep(for: .seconds(1.2))
        let delegate: PhotoDelegate = .init()
        let data: Data? = await withCheckedContinuation { continuation in
            delegate.continuation = continuation
            output.capturePhoto(with: AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg]), delegate: delegate)
        }
        await runner.stop()
        return data
    }
}

/// Starts and stops a capture session off the main thread (`startRunning` blocks).
private final class SessionRunner: @unchecked Sendable {
    private let session: AVCaptureSession

    init(session: AVCaptureSession) {
        self.session = session
    }

    func start() async {
        await Task.detached { self.session.startRunning() }.value
    }

    func stop() async {
        await Task.detached { self.session.stopRunning() }.value
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    var continuation: CheckedContinuation<Data?, Never>?

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: (any Error)?) {
        continuation?.resume(returning: error == nil ? photo.fileDataRepresentation() : nil)
        continuation = nil
    }
}
