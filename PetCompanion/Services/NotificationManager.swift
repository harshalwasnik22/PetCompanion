import Foundation
import UserNotifications

@MainActor
protocol NotificationCenterClient: AnyObject {
    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?)
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(request: UNNotificationRequest)
    func removePendingRequests(identifiers: [String])
    func pendingRequestIdentifiers() async -> [String]
}

extension UNUserNotificationCenter: NotificationCenterClient {
    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {
        self.delegate = delegate
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    func add(request: UNNotificationRequest) {
        add(request) { _ in }
    }

    func removePendingRequests(identifiers: [String]) {
        removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingRequestIdentifiers() async -> [String] {
        await pendingNotificationRequests().map(\.identifier)
    }
}

@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let categoryIdentifier = "TASK_REMINDER"
    static let openTaskActionIdentifier = "OPEN_TASK"
    static let markCompleteActionIdentifier = "MARK_COMPLETE"
    /// `nonisolated` because it is read from `init`'s default argument, which is
    /// evaluated outside the actor — main-actor isolation there is a Swift 6 error.
    nonisolated static let foregroundReminderCoalescingWindow: Duration = .milliseconds(100)
    /// Pure string logic, deliberately off the main actor: #14 derives the same
    /// identifier while scheduling, and the isolation would buy nothing.
    nonisolated private static let notificationPrefix = "task-reminder-"

    private let center: any NotificationCenterClient
    private var taskManager: TaskManager?
    private var reactionEngine: PetReactionEngine?
    private let foregroundReminderCoalescingWindow: Duration
    private var foregroundReminderCount = 0
    private var foregroundReminderTask: Task<Void, Never>?
    let reminderScheduler: ReminderScheduler
    var openTasks: () -> Void = {}

    init(
        center: any NotificationCenterClient = UNUserNotificationCenter.current(),
        taskManager: TaskManager? = nil,
        foregroundReminderCoalescingWindow: Duration = NotificationManager.foregroundReminderCoalescingWindow
    ) {
        self.center = center
        self.taskManager = taskManager
        self.foregroundReminderCoalescingWindow = foregroundReminderCoalescingWindow
        self.reminderScheduler = ReminderScheduler(center: center)
    }

    func setTaskManager(_ taskManager: TaskManager?) {
        self.taskManager = taskManager
    }

    func setReactionEngine(_ reactionEngine: PetReactionEngine?) {
        self.reactionEngine = reactionEngine
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
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            // The reminder that triggered this prompt was scheduled before
            // permission resolved, so its `add` was rejected. Reconciling here
            // means the first reminder a user ever sets still fires, instead of
            // waiting for the next launch to heal it.
            await taskManager?.rescheduleFutureReminders()
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

    func willPresent(notificationIdentifier: String) -> UNNotificationPresentationOptions {
        guard Self.taskID(from: notificationIdentifier) != nil else { return [.banner, .sound] }

        foregroundReminderCount += 1
        guard foregroundReminderTask == nil else { return [.banner, .sound] }

        let window = foregroundReminderCoalescingWindow
        foregroundReminderTask = Task { [weak self] in
            do {
                try await Task.sleep(for: window)
            } catch {
                return
            }
            guard !Task.isCancelled, let self else { return }

            let count = foregroundReminderCount
            foregroundReminderCount = 0
            foregroundReminderTask = nil
            reactionEngine?.show(event: .onReminderDue(count: count))
        }
        return [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let actionIdentifier = response.actionIdentifier
        let notificationIdentifier = response.notification.request.identifier
        await route(actionIdentifier: actionIdentifier, notificationIdentifier: notificationIdentifier)
    }

    /// The async variant, matching `didReceive` above. The completion-handler
    /// form would have to answer before hopping to the main actor, which means
    /// hard-coding the options and discarding the ones `willPresent` returns.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        await willPresent(notificationIdentifier: notification.request.identifier)
    }
}
