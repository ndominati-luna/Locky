import CoreLocation
import Foundation

/// Location Services for Locky: macOS shows the names of the Wi-Fi networks around only to an app
/// allowed to use them. Locky never reads the location itself.
@MainActor
final class LocationPermission: NSObject {
    private let manager: CLLocationManager = .init()
    private var waiters: [CheckedContinuation<Void, Never>] = []

    override init() {
        super.init()
        manager.delegate = self
    }

    var isGranted: Bool {
        switch manager.authorizationStatus {
        case .notDetermined, .denied, .restricted: false
        default: true
        }
    }

    var isDenied: Bool {
        manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted
    }

    /// Asks macOS once (it shows its own alert), and waits for the answer, at most `timeout`.
    func request(timeout: Duration = .seconds(30)) async {
        guard manager.authorizationStatus == .notDetermined else { return }
        manager.requestWhenInUseAuthorization()
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
            Task { [weak self] in
                try? await Task.sleep(for: timeout)
                self?.resumeWaiters()
            }
        }
    }

    private func resumeWaiters() {
        let waiters: [CheckedContinuation<Void, Never>] = self.waiters
        self.waiters = []
        waiters.forEach { $0.resume() }
    }
}

extension LocationPermission: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status: CLAuthorizationStatus = manager.authorizationStatus
        MainActor.assumeIsolated {
            guard status != .notDetermined else { return }
            resumeWaiters()
        }
    }
}
