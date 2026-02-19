import UserNotifications

@MainActor
public class NotificationManager {
    public static let shared = NotificationManager()

    public static let categoryIdentifier = "FUTURE_DELIVERY"
    public static let openActionIdentifier = "OPEN_ACTION"
    public static let snoozeActionIdentifier = "SNOOZE_ACTION"

    public func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    public func registerCategory() {
        let openAction = UNNotificationAction(
            identifier: Self.openActionIdentifier,
            title: "Open",
            options: [.foreground]
        )
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionIdentifier,
            title: "Snooze",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [openAction, snoozeAction],
            intentIdentifiers: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    public func scheduleNotification(for item: FutureItem) {
        let content = UNMutableNotificationContent()
        content.title = "From Past You"
        content.body = item.title ?? item.url
        content.sound = .default
        content.userInfo = ["itemId": item.id.uuidString]
        content.categoryIdentifier = Self.categoryIdentifier

        let interval = item.deliverAt.timeIntervalSinceNow
        guard interval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    public func cancelNotification(for itemId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [itemId.uuidString])
    }
}
