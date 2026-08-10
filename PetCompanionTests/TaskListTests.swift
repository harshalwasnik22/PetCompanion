import Foundation
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
