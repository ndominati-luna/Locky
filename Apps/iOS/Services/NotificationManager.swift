import Foundation
import LockyKit
import UserNotifications

/// Local notifications: lock / unlock events, unlock requests needing authentication, alerts.
@MainActor
final class NotificationManager: NSObject {
    enum Category {
        static let unlockRequest: String = "UNLOCK_REQUEST"
        static let intrusion: String = "INTRUSION"
    }

    enum Action {
        static let unlock: String = "UNLOCK"
    }

    /// The user chose "Unlock" on an unlock request (the system already authenticated them).
    var onUnlockAction: (() -> Void)?
    /// The user opened an intrusion notification.
    var onIntrusionOpened: (() -> Void)?

    private let center: UNUserNotificationCenter = .current()

    func configure() {
        center.delegate = self
        let unlock: UNNotificationAction = .init(
            identifier: Action.unlock,
            title: String(localized: "Unlock"),
            options: [.authenticationRequired],
            icon: .init(systemImageName: "lock.open.fill")
        )
        center.setNotificationCategories([
            .init(identifier: Category.unlockRequest, actions: [unlock], intentIdentifiers: []),
            .init(identifier: Category.intrusion, actions: [], intentIdentifiers: [])
        ])
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Posts a notification immediately, replacing the previous one with the same identifier.
    func post(
        identifier: String,
        body: String,
        sound: UNNotificationSound? = .default,
        category: String? = nil,
        interruption: UNNotificationInterruptionLevel = .active
    ) {
        let content: UNMutableNotificationContent = .init()
        content.title = "Locky"
        content.body = body
        content.sound = sound
        content.interruptionLevel = interruption
        if let category {
            content.categoryIdentifier = category
        }
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    /// Sound of a theme, for notifications.
    func sound(for theme: SoundTheme) -> UNNotificationSound? {
        guard let fileName = theme.fileName else { return nil }
        return .init(named: .init("\(fileName).caf"))
    }

    func clearBadge() {
        center.setBadgeCount(0)
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action: String = response.actionIdentifier
        let category: String = response.notification.request.content.categoryIdentifier
        await MainActor.run {
            if action == Action.unlock {
                onUnlockAction?()
            } else if category == Category.intrusion || category.isEmpty && action == UNNotificationDefaultActionIdentifier {
                onIntrusionOpened?()
            }
        }
    }
}
