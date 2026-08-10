import Foundation
import SwiftData

@MainActor
final class TaskManager {
    enum Error: LocalizedError {
        case invalidTitle

        var errorDescription: String? {
            "Enter a task title."
        }
    }

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func create(title: String, notes: String, dueAt: Date?, reminderAt: Date?) throws {
        let input = try validatedInput(title: title, notes: notes)
        modelContext.insert(TaskItem(
            title: input.title,
            notes: input.notes,
            dueAt: dueAt,
            reminderAt: reminderAt
        ))
        try save()
    }

    func update(_ task: TaskItem, title: String, notes: String, dueAt: Date?, reminderAt: Date?) throws {
        let input = try validatedInput(title: title, notes: notes)
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

    private func save() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
