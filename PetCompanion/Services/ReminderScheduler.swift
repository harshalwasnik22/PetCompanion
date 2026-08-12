import Foundation
import UserNotifications

@MainActor
final class ReminderScheduler {
    private let center: any NotificationCenterClient

    init(center: any NotificationCenterClient) {
        self.center = center
    }

    func schedule(_ task: TaskItem, now: Date = .now) {
        guard isEligible(task, now: now), let reminderAt = task.reminderAt else { return }

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

    /// Takes an identifier rather than the model because the caller may have
    /// already deleted it — see `TaskManager.delete`.
    func cancel(for taskID: UUID) {
        center.removePendingRequests(identifiers: [NotificationManager.notificationIdentifier(for: taskID)])
    }

    /// Restores every eligible reminder and drops requests whose task is gone,
    /// completed, or past. Removal matters as much as adding: the database
    /// change is saved before the request is cancelled, so a crash in that
    /// window would otherwise leave a notification firing forever for a task
    /// that no longer exists.
    func reconcile(_ tasks: [TaskItem], now: Date = .now) async {
        let wanted = Set(
            tasks.filter { isEligible($0, now: now) }
                .map { NotificationManager.notificationIdentifier(for: $0.id) }
        )
        let stale = await center.pendingRequestIdentifiers().filter {
            NotificationManager.taskID(from: $0) != nil && !wanted.contains($0)
        }
        if !stale.isEmpty {
            center.removePendingRequests(identifiers: stale)
        }
        tasks.forEach { schedule($0, now: now) }
    }

    private func isEligible(_ task: TaskItem, now: Date) -> Bool {
        guard task.status == .pending, let reminderAt = task.reminderAt else { return false }
        return reminderAt > now
    }
}
