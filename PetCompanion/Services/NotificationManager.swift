import Foundation
import UserNotifications

@MainActor
protocol NotificationCenterClient: AnyObject {
    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?)
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
}

extension UNUserNotificationCenter: NotificationCenterClient {
    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {
        self.delegate = delegate
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }
}

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let categoryIdentifier = "TASK_REMINDER"
    static let openTaskActionIdentifier = "OPEN_TASK"
    static let markCompleteActionIdentifier = "MARK_COMPLETE"
    /// Pure string logic, deliberately off the main actor: #14 derives the same
    /// identifier while scheduling, and the isolation would buy nothing.
    nonisolated private static let notificationPrefix = "task-reminder-"

    private let center: any NotificationCenterClient
    private let taskManager: TaskManager?
    var openTasks: () -> Void = {}

    init(
        center: any NotificationCenterClient = UNUserNotificationCenter.current(),
        taskManager: TaskManager? = nil
    ) {
        self.center = center
        self.taskManager = taskManager
    }

    func registerCategory() {
        center.setDelegate(self)
        center.setNotificationCategories([UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [
                UNNotificationAction(
                    identifier: Self.openTaskActionIdentifier,
                    title: "Open Task",
                    options: .foreground
                ),
                UNNotificationAction(identifier: Self.markCompleteActionIdentifier, title: "Mark Complete")
            ],
            intentIdentifiers: []
        )])
    }

    func requestAuthorizationForReminder() {
        Task {
            guard await center.authorizationStatus() == .notDetermined else { return }
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.authorizationStatus()
    }

    nonisolated static func notificationIdentifier(for taskID: UUID) -> String {
        notificationPrefix + taskID.uuidString
    }

    nonisolated static func taskID(from notificationIdentifier: String) -> UUID? {
        guard notificationIdentifier.hasPrefix(notificationPrefix) else { return nil }
        return UUID(uuidString: String(notificationIdentifier.dropFirst(notificationPrefix.count)))
    }

    func route(actionIdentifier: String, notificationIdentifier: String) {
        guard let taskID = Self.taskID(from: notificationIdentifier) else { return }

        switch actionIdentifier {
        case Self.openTaskActionIdentifier, UNNotificationDefaultActionIdentifier:
            openTasks()
        case Self.markCompleteActionIdentifier:
            try? taskManager?.complete(id: taskID)
        default:
            break
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier
        await route(actionIdentifier: actionIdentifier, notificationIdentifier: notificationIdentifier)
    }
}
