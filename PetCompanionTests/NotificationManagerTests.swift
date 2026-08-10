import Foundation
import SwiftData
import Testing
import UserNotifications
@testable import PetCompanion

@Test func taskReminderIdentifierRoundTrips() {
    let id = UUID(uuidString: "7B51EB2C-752A-4D4A-9FB6-6EFDB49523E4")!

    let identifier = NotificationManager.notificationIdentifier(for: id)

    #expect(identifier == "task-reminder-7B51EB2C-752A-4D4A-9FB6-6EFDB49523E4")
    #expect(NotificationManager.taskID(from: identifier) == id)
}

@Test func malformedTaskReminderIdentifierIsRejected() {
    #expect(NotificationManager.taskID(from: "task-reminder-not-a-uuid") == nil)
    #expect(NotificationManager.taskID(from: "other-7B51EB2C-752A-4D4A-9FB6-6EFDB49523E4") == nil)
}

@MainActor
@Test func authorizationStatusAlwaysReflectsTheNotificationCenter() async {
    let center = FakeNotificationCenter(status: .denied)
    let manager = NotificationManager(center: center)

    #expect(await manager.authorizationStatus() == .denied)
    center.status = .authorized
    #expect(await manager.authorizationStatus() == .authorized)
}

@MainActor
@Test func openTaskActionRoutesToTheTasksWindow() {
    let manager = NotificationManager(center: FakeNotificationCenter())
    var didOpenTasks = false
    manager.openTasks = { didOpenTasks = true }

    manager.route(
        actionIdentifier: NotificationManager.openTaskActionIdentifier,
        notificationIdentifier: "task-reminder-7B51EB2C-752A-4D4A-9FB6-6EFDB49523E4"
    )

    #expect(didOpenTasks)
}

@MainActor
@Test func markCompleteActionCompletesTheMatchingTask() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let task = TaskItem(title: "Finish issue")
    context.insert(task)
    try context.save()
    let manager = NotificationManager(
        center: FakeNotificationCenter(),
        taskManager: TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    )

    manager.route(
        actionIdentifier: NotificationManager.markCompleteActionIdentifier,
        notificationIdentifier: NotificationManager.notificationIdentifier(for: task.id)
    )

    #expect(task.status == .completed)
    #expect(task.completedAt != nil)
}

@MainActor
private final class FakeNotificationCenter: NotificationCenterClient {
    var status: UNAuthorizationStatus

    init(status: UNAuthorizationStatus = .denied) {
        self.status = status
    }

    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {}
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { false }
}
