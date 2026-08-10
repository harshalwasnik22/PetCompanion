import Foundation
import SwiftData

enum TaskStatus: String, Codable, Sendable {
    case pending
    case completed
}

/// Named `TaskItem` rather than `Task` so the model never shadows
/// `_Concurrency.Task` in files that also use structured concurrency.
@Model
final class TaskItem {
    var id: UUID
    var title: String
    var notes: String?
    var status: TaskStatus
    var dueAt: Date?
    var reminderAt: Date?
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        notes: String? = nil,
        status: TaskStatus = .pending,
        dueAt: Date? = nil,
        reminderAt: Date? = nil,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.status = status
        self.dueAt = dueAt
        self.reminderAt = reminderAt
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}
