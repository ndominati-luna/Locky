import Foundation
import UserNotifications

/// Notifications of the Mac app.
@MainActor
final class MacNotifier: NSObject {
    enum Identifier {
        static let status: String = "status"
        static let battery: String = "battery"
        /// Locky may not use the camera: clicking opens the Camera privacy settings.
        static let camera: String = "camera"
    }

    /// The notification about the camera was clicked.
    var onOpenCameraSettings: (() -> Void)?

    private let center: UNUserNotificationCenter = .current()

    func configure() {
        center.delegate = self
    }

    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    func post(identifier: String, title: String, body: String, timeSensitive: Bool = false, category: String? = nil) {
        let content: UNMutableNotificationContent = .init()
        content.title = title
        content.body = body
        content.interruptionLevel = timeSensitive ? .timeSensitive : .active
        if let category {
            content.categoryIdentifier = category
        }
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    func remove(_ identifier: String) {
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }
}

extension MacNotifier: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        // The intrusion alerts of iCloud are meant for the iPhone: subscriptions belong to the
        // iCloud account, so they reach the Mac too since it registers for pushes.
        guard !(notification.request.trigger is UNPushNotificationTrigger) else { return [] }
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let identifier: String = response.notification.request.identifier
        await handleClick(on: identifier)
    }

    private func handleClick(on identifier: String) {
        if identifier == Identifier.camera {
            onOpenCameraSettings?()
        }
    }
}
