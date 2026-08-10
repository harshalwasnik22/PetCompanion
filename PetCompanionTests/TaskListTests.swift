import Foundation
import SwiftData
import Testing
@testable import PetCompanion

@Test func taskEditorInputTrimsContentAndRejectsBlankTitles() {
    #expect(TaskEditorInput(title: "  ", notes: "notes").validatedTitle == nil)
    #expect(TaskEditorInput(title: "  Feed Momo  ", notes: "  At noon  ").validatedTitle == "Feed Momo")
    #expect(TaskEditorInput(title: "Task", notes: "   ").normalizedNotes == nil)
    #expect(TaskEditorInput(title: "Task", notes: "  Details  ").normalizedNotes == "Details")
}

@Test func taskListOrdersPendingByDateThenCreationAndCompletedNewestFirst() {
    let now = Date(timeIntervalSince1970: 1_000)
    let undated = TaskItem(title: "Undated", createdAt: now)
    let later = TaskItem(title: "Later", dueAt: now.addingTimeInterval(200), createdAt: now.addingTimeInterval(20))
    let sooner = TaskItem(title: "Sooner", reminderAt: now.addingTimeInterval(100), createdAt: now.addingTimeInterval(10))

    #expect(TaskListOrdering.pending([undated, later, sooner]).map(\.title) == ["Sooner", "Later", "Undated"])

    let older = TaskItem(title: "Older", status: .completed, completedAt: now)
    let newer = TaskItem(title: "Newer", status: .completed, completedAt: now.addingTimeInterval(100))
    #expect(TaskListOrdering.completed([older, newer]).map(\.title) == ["Newer", "Older"])
}

@Test func tasksSharingADateFallBackToCreationOrder() {
    let now = Date(timeIntervalSince1970: 1_000)
    let due = now.addingTimeInterval(500)
    let second = TaskItem(title: "Second", dueAt: due, createdAt: now.addingTimeInterval(10))
    let first = TaskItem(title: "First", dueAt: due, createdAt: now)

    #expect(TaskListOrdering.pending([second, first]).map(\.title) == ["First", "Second"])
}

@Test func eachSectionExcludesTheOtherStatus() {
    let pending = TaskItem(title: "Pending")
    let done = TaskItem(title: "Done", status: .completed, completedAt: .now)

    #expect(TaskListOrdering.pending([pending, done]).map(\.title) == ["Pending"])
    #expect(TaskListOrdering.completed([pending, done]).map(\.title) == ["Done"])
}

@MainActor
@Test func taskManagerValidatesAndCreatesTasks() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())

    #expect(throws: TaskManager.Error.invalidTitle) {
        try manager.create(title: "  ", notes: "Ignored", dueAt: nil, reminderAt: nil)
    }
    #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)

    try manager.create(title: "  Feed Momo  ", notes: "  At noon  ", dueAt: nil, reminderAt: nil)
    let stored = try #require(context.fetch(FetchDescriptor<TaskItem>()).first)
    #expect(stored.title == "Feed Momo")
    #expect(stored.notes == "At noon")
}

@MainActor
@Test func futureReminderPersists() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    let now = Date(timeIntervalSince1970: 1_000)
    let reminderAt = now.addingTimeInterval(60)

    try manager.create(title: "Feed Momo", notes: "", dueAt: nil, reminderAt: reminderAt, now: now)

    let stored = try #require(context.fetch(FetchDescriptor<TaskItem>()).first)
    #expect(stored.reminderAt == reminderAt)
}

@MainActor
@Test func pastReminderIsRejectedWithoutInserting() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    let now = Date(timeIntervalSince1970: 1_000)

    #expect(throws: TaskManager.Error.reminderInPast) {
        try manager.create(
            title: "Feed Momo",
            notes: "",
            dueAt: nil,
            reminderAt: now.addingTimeInterval(-1),
            now: now
        )
    }
    #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
}

@MainActor
@Test func taskWithoutReminderRemainsValid() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())

    try manager.create(
        title: "Feed Momo",
        notes: "",
        dueAt: nil,
        reminderAt: nil,
        now: Date(timeIntervalSince1970: 1_000)
    )

    let stored = try #require(context.fetch(FetchDescriptor<TaskItem>()).first)
    #expect(stored.reminderAt == nil)
}

/// The other half of the `update` guard: skipping validation for an unchanged
/// reminder must not become a way to set a new past reminder on an existing task.
@MainActor
@Test func movingAReminderIntoThePastIsStillRejectedOnEdit() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    let now = Date(timeIntervalSince1970: 1_000)
    let task = TaskItem(title: "Old title", reminderAt: now.addingTimeInterval(60))
    context.insert(task)
    try context.save()

    #expect(throws: TaskManager.Error.reminderInPast) {
        try manager.update(
            task,
            title: "New title",
            notes: "",
            dueAt: nil,
            reminderAt: now.addingTimeInterval(-60),
            now: now
        )
    }
    #expect(task.title == "Old title")
}

@MainActor
@Test func unchangedPastReminderDoesNotBlockEditing() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    let now = Date(timeIntervalSince1970: 1_000)
    let reminderAt = now.addingTimeInterval(-60)
    let task = TaskItem(title: "Old title", reminderAt: reminderAt)
    context.insert(task)
    try context.save()

    try manager.update(
        task,
        title: "New title",
        notes: "",
        dueAt: nil,
        reminderAt: reminderAt,
        now: now
    )

    #expect(task.title == "New title")
    #expect(task.reminderAt == reminderAt)
}

@MainActor
@Test func taskManagerCompletesAndDeletesTasks() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    let task = TaskItem(title: "Finish issue")
    context.insert(task)
    try context.save()

    try manager.complete(task)
    #expect(task.status == .completed)
    #expect(task.completedAt != nil)

    try manager.delete(task)
    #expect(try context.fetchCount(FetchDescriptor<TaskItem>()) == 0)
}

/// `complete` guards on the current status specifically so a second call cannot
/// move `completedAt` forward — a re-completed task would otherwise jump to the
/// top of the Completed section.
@MainActor
@Test func completingAnAlreadyCompletedTaskKeepsTheOriginalTimestamp() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    let task = TaskItem(title: "Finish issue")
    context.insert(task)

    try manager.complete(task)
    let firstCompletion = try #require(task.completedAt)

    try manager.complete(task)
    #expect(task.completedAt == firstCompletion)
}

@MainActor
@Test func editingACompletedTaskDoesNotReopenIt() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = TaskManager(modelContext: context, reactionEngine: PetReactionEngine())
    let completedAt = Date(timeIntervalSince1970: 1_000)
    let task = TaskItem(title: "Old title", status: .completed, completedAt: completedAt)
    context.insert(task)
    try context.save()

    try manager.update(task, title: "New title", notes: "Notes", dueAt: nil, reminderAt: nil)

    #expect(task.title == "New title")
    #expect(task.status == .completed)
    #expect(task.completedAt == completedAt)
}

@MainActor
@Test func creatingATaskFiresTheAddedReactionOnce() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let engine = PetReactionEngine()
    let manager = TaskManager(modelContext: context, reactionEngine: engine)
    let initialToken = engine.reactionToken

    try manager.create(title: "Feed Momo", notes: "", dueAt: nil, reminderAt: nil)

    #expect(engine.mood == .happy)
    #expect(engine.bubble == "I’ll remember that!")
    #expect(engine.priority == 60)
    #expect(engine.reactionToken != initialToken)
}

@MainActor
@Test func completingATaskFiresTheCompletedReactionOnce() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let engine = PetReactionEngine()
    let manager = TaskManager(modelContext: context, reactionEngine: engine)
    let task = TaskItem(title: "Finish issue")
    context.insert(task)
    try context.save()

    try manager.complete(task)
    let completionToken = engine.reactionToken

    #expect(engine.mood == .excited)
    #expect(engine.bubble == "You did it!")
    #expect(engine.priority == 80)

    try manager.complete(task)
    #expect(engine.reactionToken == completionToken)
}

@MainActor
@Test func validationFailureFiresNoReaction() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let engine = PetReactionEngine()
    let manager = TaskManager(modelContext: context, reactionEngine: engine)
    let initialToken = engine.reactionToken

    #expect(throws: TaskManager.Error.invalidTitle) {
        try manager.create(title: "  ", notes: "", dueAt: nil, reminderAt: nil)
    }

    #expect(engine.mood == .idle)
    #expect(engine.bubble == nil)
    #expect(engine.priority == 0)
    #expect(engine.reactionToken == initialToken)
}
