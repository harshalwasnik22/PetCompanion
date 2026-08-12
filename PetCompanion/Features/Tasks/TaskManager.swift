import Foundation
import SwiftData

@MainActor
final class TaskManager {
    enum Error: LocalizedError {
        case invalidTitle
        case reminderInPast

        var errorDescription: String? {
            switch self {
            case .invalidTitle: "Enter a task title."
            case .reminderInPast: "Choose a reminder time in the future."
            }
        }
    }

    private let modelContext: ModelContext
    private let reactionEngine: PetReactionEngine
    private let notificationManager: NotificationManager?

    init(
        modelContext: ModelContext,
        reactionEngine: PetReactionEngine,
        notificationManager: NotificationManager? = nil
    ) {
        self.modelContext = modelContext
        self.reactionEngine = reactionEngine
        self.notificationManager = notificationManager
    }

    func create(title: String, notes: String, dueAt: Date?, reminderAt: Date?, now: Date = .now) throws {
        let input = try validatedInput(title: title, notes: notes)
        try validate(reminderAt: reminderAt, now: now)
        let task = TaskItem(
            title: input.title,
            notes: input.notes,
            dueAt: dueAt,
            reminderAt: reminderAt
        )
        modelContext.insert(task)
        try save()
        notificationManager?.reminderScheduler.schedule(task, now: now)
        reactionEngine.show(event: .onTaskAdded)
        if reminderAt != nil { notificationManager?.requestAuthorizationForReminder() }
    }

    func update(
        _ task: TaskItem,
        title: String,
        notes: String,
        dueAt: Date?,
        reminderAt: Date?,
        now: Date = .now
    ) throws {
        let input = try validatedInput(title: title, notes: notes)
        // An unchanged expired reminder must not block edits to the rest of the task.
        if reminderAt != task.reminderAt {
            try validate(reminderAt: reminderAt, now: now)
        }
        task.title = input.title
        task.notes = input.notes
        task.dueAt = dueAt
        task.reminderAt = reminderAt
        try save()
        if let reminderAt, reminderAt > now {
            notificationManager?.reminderScheduler.schedule(task, now: now)
        } else {
            notificationManager?.reminderScheduler.cancel(for: task.id)
        }
        if reminderAt != nil { notificationManager?.requestAuthorizationForReminder() }
    }

    func complete(_ task: TaskItem) throws {
        guard task.status != .completed else { return }
        task.status = .completed
        task.completedAt = .now
        try save()
        notificationManager?.reminderScheduler.cancel(for: task.id)
        reactionEngine.show(event: .onTaskCompleted)
    }

    func complete(id: UUID) throws {
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        guard let task = try modelContext.fetch(descriptor).first else { return }
        try complete(task)
    }

    func delete(_ task: TaskItem) throws {
        // SwiftData may invalidate the model once the delete is saved, so the
        // identifier has to be read while the object is still valid.
        let taskID = task.id
        modelContext.delete(task)
        try save()
        notificationManager?.reminderScheduler.cancel(for: taskID)
    }

    /// Re-adds every future reminder and clears the rest. `add` with an existing
    /// identifier replaces rather than duplicates, so running this at launch — and
    /// again once permission is granted — is safe, and it restores requests that
    /// were dropped while permission was denied.
    ///
    /// The pending/future filtering happens in Swift rather than the predicate:
    /// `#Predicate` cannot compare a stored enum, and a personal task list is far
    /// too small for the round trip to matter.
    func rescheduleFutureReminders(now: Date = .now) async {
        guard let scheduler = notificationManager?.reminderScheduler else { return }
        // Read the pending requests before fetching, so that nothing can be
        // deleted between fetching the models and acting on them.
        let pending = await scheduler.pendingTaskReminderIdentifiers()
        let descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.reminderAt != nil })
        guard let tasks = try? modelContext.fetch(descriptor) else { return }
        scheduler.reconcile(tasks, pending: pending, now: now)
    }

    private func validatedInput(title: String, notes: String) throws -> (title: String, notes: String?) {
        let input = TaskEditorInput(title: title, notes: notes)
        guard let title = input.validatedTitle else { throw Error.invalidTitle }
        return (title, input.normalizedNotes)
    }

    private func validate(reminderAt: Date?, now: Date) throws {
        if let reminderAt, reminderAt < now { throw Error.reminderInPast }
    }

    private func save() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
