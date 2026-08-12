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
@Test func schedulerCreatesANonRepeatingCategorizedRequest() async throws {
    let center = FakeNotificationCenter()
    let scheduler = ReminderScheduler(center: center)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let reminderAt = now.addingTimeInterval(60)
    let task = TaskItem(title: "Feed Momo", reminderAt: reminderAt)

    scheduler.schedule(task, now: now)

    let identifier = NotificationManager.notificationIdentifier(for: task.id)
    #expect(await center.pendingRequestIdentifiers() == [identifier])
    let request = try #require(center.pendingRequests[identifier])
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(request.content.title == "Feed Momo")
    #expect(request.content.categoryIdentifier == NotificationManager.categoryIdentifier)
    #expect(trigger.repeats == false)
    #expect(trigger.nextTriggerDate() == reminderAt)
}

@MainActor
@Test func schedulingTheSameTaskReplacesItsExistingRequest() async throws {
    let center = FakeNotificationCenter()
    let scheduler = ReminderScheduler(center: center)
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let task = TaskItem(title: "Feed Momo", reminderAt: now.addingTimeInterval(60))

    scheduler.schedule(task, now: now)
    task.reminderAt = now.addingTimeInterval(120)
    scheduler.schedule(task, now: now)

    let identifier = NotificationManager.notificationIdentifier(for: task.id)
    #expect(await center.pendingRequestIdentifiers() == [identifier])
    #expect(center.addedIdentifiers == [identifier, identifier])
    #expect(center.removedIdentifiers.isEmpty)
    let request = try #require(center.pendingRequests[identifier])
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.nextTriggerDate() == now.addingTimeInterval(120))
}

@MainActor
@Test func schedulerSkipsPastReminders() async {
    let center = FakeNotificationCenter()
    let scheduler = ReminderScheduler(center: center)
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    scheduler.schedule(TaskItem(title: "Past", reminderAt: now.addingTimeInterval(-1)), now: now)

    #expect(await center.pendingRequestIdentifiers().isEmpty)
}

@MainActor
@Test func taskManagerSchedulesUpdatesAndCancelsReminderRequests() async throws {
    let center = FakeNotificationCenter()
    let notificationManager = NotificationManager(center: center)
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(
        modelContext: context,
        reactionEngine: PetReactionEngine(),
        notificationManager: notificationManager
    )
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    try manager.create(
        title: "Feed Momo",
        notes: "",
        dueAt: nil,
        reminderAt: now.addingTimeInterval(60),
        now: now
    )
    let task = try #require(context.fetch(FetchDescriptor<TaskItem>()).first)
    let identifier = NotificationManager.notificationIdentifier(for: task.id)
    #expect(await center.pendingRequestIdentifiers() == [identifier])

    try manager.update(
        task,
        title: task.title,
        notes: "",
        dueAt: nil,
        reminderAt: now.addingTimeInterval(120),
        now: now
    )
    #expect(await center.pendingRequestIdentifiers() == [identifier])
    #expect(center.addedIdentifiers == [identifier, identifier])
    #expect(center.removedIdentifiers.isEmpty)

    try manager.update(task, title: task.title, notes: "", dueAt: nil, reminderAt: nil, now: now)
    #expect(await center.pendingRequestIdentifiers().isEmpty)
    #expect(center.removedIdentifiers == [identifier])

    try manager.update(
        task,
        title: task.title,
        notes: "",
        dueAt: nil,
        reminderAt: now.addingTimeInterval(180),
        now: now
    )
    try manager.complete(task)
    #expect(await center.pendingRequestIdentifiers().isEmpty)
    #expect(center.removedIdentifiers == [identifier, identifier])

    let deletedTask = TaskItem(title: "Walk Momo", reminderAt: now.addingTimeInterval(240))
    context.insert(deletedTask)
    try context.save()
    notificationManager.reminderScheduler.schedule(deletedTask, now: now)
    let deletedIdentifier = NotificationManager.notificationIdentifier(for: deletedTask.id)
    try manager.delete(deletedTask)
    #expect(await center.pendingRequestIdentifiers().isEmpty)
    #expect(center.removedIdentifiers == [identifier, identifier, deletedIdentifier])
}

@MainActor
@Test func updatingAReminderAtNowCancelsThePreviousRequest() async throws {
    let center = FakeNotificationCenter()
    let notificationManager = NotificationManager(center: center)
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(
        modelContext: context,
        reactionEngine: PetReactionEngine(),
        notificationManager: notificationManager
    )
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    try manager.create(
        title: "Feed Momo",
        notes: "",
        dueAt: nil,
        reminderAt: now.addingTimeInterval(60),
        now: now
    )
    let task = try #require(context.fetch(FetchDescriptor<TaskItem>()).first)
    let identifier = NotificationManager.notificationIdentifier(for: task.id)

    try manager.update(task, title: task.title, notes: "", dueAt: nil, reminderAt: now, now: now)

    #expect(await center.pendingRequestIdentifiers().isEmpty)
    #expect(center.removedIdentifiers == [identifier])
}

@MainActor
@Test func reconciliationRestoresOnlyFutureIncompleteReminderRequests() async throws {
    let center = FakeNotificationCenter(status: .denied)
    let notificationManager = NotificationManager(center: center)
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(
        modelContext: context,
        reactionEngine: PetReactionEngine(),
        notificationManager: notificationManager
    )
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let futureTask = TaskItem(title: "Future", reminderAt: now.addingTimeInterval(60))
    context.insert(futureTask)
    context.insert(TaskItem(title: "Past", reminderAt: now.addingTimeInterval(-60)))
    context.insert(TaskItem(title: "Done", status: .completed, reminderAt: now.addingTimeInterval(60)))
    try context.save()

    await manager.rescheduleFutureReminders(now: now)
    let identifier = NotificationManager.notificationIdentifier(for: futureTask.id)
    #expect(await center.pendingRequestIdentifiers().isEmpty)

    center.status = .authorized
    await manager.rescheduleFutureReminders(now: now)
    #expect(await center.pendingRequestIdentifiers() == [identifier])
    #expect(center.addedIdentifiers == [identifier, identifier])
}

@MainActor
@Test func reconciliationRemovesRequestsWhoseTaskIsGoneOrDone() async throws {
    let center = FakeNotificationCenter()
    let notificationManager = NotificationManager(center: center)
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(
        modelContext: context,
        reactionEngine: PetReactionEngine(),
        notificationManager: notificationManager
    )
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let survivor = TaskItem(title: "Survivor", reminderAt: now.addingTimeInterval(60))
    context.insert(survivor)
    try context.save()
    notificationManager.reminderScheduler.schedule(survivor, now: now)

    // Stands in for a crash between saving a delete and cancelling its request.
    let orphanIdentifier = NotificationManager.notificationIdentifier(for: UUID())
    center.add(request: UNNotificationRequest(
        identifier: orphanIdentifier,
        content: UNMutableNotificationContent(),
        trigger: nil
    ))
    let foreignIdentifier = "habit-streak-1"
    center.add(request: UNNotificationRequest(
        identifier: foreignIdentifier,
        content: UNMutableNotificationContent(),
        trigger: nil
    ))

    await manager.rescheduleFutureReminders(now: now)

    let survivorIdentifier = NotificationManager.notificationIdentifier(for: survivor.id)
    #expect(await center.pendingRequestIdentifiers() == [foreignIdentifier, survivorIdentifier].sorted())
    #expect(center.removedIdentifiers == [orphanIdentifier])
}

@MainActor
@Test func reconciliationDoesNotResurrectATaskDeletedWhileItRan() async throws {
    let center = FakeNotificationCenter()
    let notificationManager = NotificationManager(center: center)
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(
        modelContext: context,
        reactionEngine: PetReactionEngine(),
        notificationManager: notificationManager
    )
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let doomed = TaskItem(title: "Doomed", reminderAt: now.addingTimeInterval(60))
    context.insert(doomed)
    try context.save()
    notificationManager.reminderScheduler.schedule(doomed, now: now)
    let identifier = NotificationManager.notificationIdentifier(for: doomed.id)
    #expect(await center.pendingRequestIdentifiers() == [identifier])

    // Deletes the task inside reconciliation's only suspension point.
    center.duringPendingLookup = { try? manager.delete(doomed) }
    await manager.rescheduleFutureReminders(now: now)
    center.duringPendingLookup = nil

    #expect(await center.pendingRequestIdentifiers().isEmpty)
}

@MainActor
@Test func grantingAuthorizationReschedulesTheReminderThatPromptedIt() async throws {
    let center = FakeNotificationCenter(status: .notDetermined)
    center.authorizationGrant = true
    let notificationManager = NotificationManager(center: center)
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(
        modelContext: context,
        reactionEngine: PetReactionEngine(),
        notificationManager: notificationManager
    )
    notificationManager.setTaskManager(manager)
    let now = Date.now.addingTimeInterval(60)

    try manager.create(title: "Feed Momo", notes: "", dueAt: nil, reminderAt: now)
    let task = try #require(context.fetch(FetchDescriptor<TaskItem>()).first)
    let identifier = NotificationManager.notificationIdentifier(for: task.id)

    // The `add` during `create` was rejected because permission had not resolved.
    #expect(await center.pendingRequestIdentifiers().isEmpty)

    await center.waitForAdds(2)
    #expect(await center.pendingRequestIdentifiers() == [identifier])
}

@MainActor
private final class FakeNotificationCenter: NotificationCenterClient {
    var status: UNAuthorizationStatus
    var authorizationGrant = false
    private(set) var addedIdentifiers: [String] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var pendingRequests: [String: UNNotificationRequest] = [:]
    /// Runs inside `pendingRequestIdentifiers`, letting a test land a mutation in
    /// the one suspension point reconciliation has.
    var duringPendingLookup: (() -> Void)?

    init(status: UNAuthorizationStatus = .authorized) {
        self.status = status
    }

    func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {}
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}
    func authorizationStatus() async -> UNAuthorizationStatus { status }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        guard authorizationGrant else { return false }
        status = .authorized
        return true
    }
    func add(request: UNNotificationRequest) {
        addedIdentifiers.append(request.identifier)
        guard status == .authorized else { return }
        pendingRequests[request.identifier] = request
    }

    /// Yields until `count` adds have been recorded. `requestAuthorizationForReminder`
    /// reschedules on a detached `Task`, so the effect lands after an await rather
    /// than inline. Bounded so a regression fails the expectation instead of hanging.
    func waitForAdds(_ count: Int, iterations: Int = 1_000) async {
        for _ in 0..<iterations where addedIdentifiers.count < count {
            await Task.yield()
        }
    }
    func removePendingRequests(identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
        identifiers.forEach { pendingRequests.removeValue(forKey: $0) }
    }
    func pendingRequestIdentifiers() async -> [String] {
        duringPendingLookup?()
        return pendingRequests.keys.sorted()
    }
}
