import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
    }

    func scheduleNotification(for item: FutureItem) {
        let content = UNMutableNotificationContent()
        content.title = "From Past You"
        content.body = item.title ?? item.url
        content.sound = .default
        content.userInfo = ["itemId": item.id.uuidString]

        let interval = item.deliverAt.timeIntervalSinceNow
        guard interval > 0 else { return }

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request)
    }

    func cancelNotification(for itemId: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [itemId.uuidString])
    }
}
