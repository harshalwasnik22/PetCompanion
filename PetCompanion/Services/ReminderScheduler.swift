import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler {
    private let center: any NotificationCenterClient

    init(center: any NotificationCenterClient) {
        self.center = center
    }

    func schedule(_ task: TaskItem, now: Date = .now) {
        guard task.status == .pending, let reminderAt = task.reminderAt, reminderAt > now else { return }

        let content = UNMutableNotificationContent()
        content.title = task.title
        content.categoryIdentifier = NotificationManager.categoryIdentifier
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
                from: reminderAt
            ),
            repeats: false
        )
        center.add(request: UNNotificationRequest(
            identifier: NotificationManager.notificationIdentifier(for: task.id),
            content: content,
            trigger: trigger
        ))
    }

    func cancel(for task: TaskItem) {
        center.removePendingRequests(identifiers: [NotificationManager.notificationIdentifier(for: task.id)])
    }

    func reconcile(_ tasks: [TaskItem], now: Date = .now) {
        tasks.forEach { schedule($0, now: now) }
    }
}
