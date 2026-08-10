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

    init(modelContext: ModelContext, reactionEngine: PetReactionEngine) {
        self.modelContext = modelContext
        self.reactionEngine = reactionEngine
    }

    func create(title: String, notes: String, dueAt: Date?, reminderAt: Date?, now: Date = .now) throws {
        let input = try validatedInput(title: title, notes: notes)
        try validate(reminderAt: reminderAt, now: now)
        modelContext.insert(TaskItem(
            title: input.title,
            notes: input.notes,
            dueAt: dueAt,
            reminderAt: reminderAt
        ))
        try save()
        reactionEngine.show(event: .onTaskAdded)
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
    }

    func complete(_ task: TaskItem) throws {
        guard task.status != .completed else { return }
        task.status = .completed
        task.completedAt = .now
        try save()
        reactionEngine.show(event: .onTaskCompleted)
    }

    func delete(_ task: TaskItem) throws {
        modelContext.delete(task)
        try save()
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
