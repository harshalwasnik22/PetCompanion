import SwiftData
import SwiftUI

struct TaskEditorInput {
    var title: String
    var notes: String

    var validatedTitle: String? {
        let value = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var normalizedNotes: String? {
        let value = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

enum TaskListOrdering {
    static func pending(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.status == .pending }.sorted {
            switch (nextDate(for: $0), nextDate(for: $1)) {
            case let (lhs?, rhs?) where lhs != rhs: lhs < rhs
            case (_?, nil): true
            case (nil, _?): false
            default: $0.createdAt < $1.createdAt
            }
        }
    }

    static func completed(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.filter { $0.status == .completed }.sorted {
            ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
        }
    }

    private static func nextDate(for task: TaskItem) -> Date? {
        [task.reminderAt, task.dueAt].compactMap { $0 }.min()
    }
}

/// Identity for the editor sheet.
///
/// The sheet is presented by `item:` rather than `isPresented:` so each distinct
/// task gets its own `@State`. With `isPresented:` SwiftUI can reuse the previous
/// presentation's state, and `TaskEditorSheet.save()` writes that state onto
/// whichever task was passed in — editing one task after another would copy the
/// first task's title over the second.
private enum TaskEditorMode: Identifiable {
    case create
    case edit(TaskItem)

    var id: String {
        switch self {
        case .create: "create"
        case .edit(let task): task.id.uuidString
        }
    }

    var task: TaskItem? {
        guard case .edit(let task) = self else { return nil }
        return task
    }
}

@MainActor
struct TaskListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tasks: [TaskItem]
    @State private var editorMode: TaskEditorMode?
    @State private var errorMessage: String?

    private var pending: [TaskItem] { TaskListOrdering.pending(tasks) }
    private var completed: [TaskItem] { TaskListOrdering.completed(tasks) }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Tasks").font(.title2.bold())
                    Text("\(pending.count) pending").foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add Task", systemImage: "plus") { presentEditor() }
                    .keyboardShortcut("n")
            }
            .padding()

            Divider()

            if tasks.isEmpty {
                ContentUnavailableView {
                    Label("No Tasks", systemImage: "checklist")
                } description: {
                    Text("Add a task to get started.")
                } actions: {
                    Button("Add Task") { presentEditor() }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Pending") {
                        if pending.isEmpty { Text("Nothing pending").foregroundStyle(.secondary) }
                        ForEach(pending) { task in row(task) }
                    }

                    Section("Completed") {
                        if completed.isEmpty { Text("No completed tasks").foregroundStyle(.secondary) }
                        ForEach(completed) { task in row(task) }
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .sheet(item: $editorMode) { mode in
            TaskEditorSheet(task: mode.task)
        }
        .alert("Task could not be saved", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    @ViewBuilder
    private func row(_ task: TaskItem) -> some View {
        TaskRow(task: task) {
            task.status = task.status == .pending ? .completed : .pending
            task.completedAt = task.status == .completed ? .now : nil
            save()
        } onEdit: {
            presentEditor(task)
        } onDelete: {
            modelContext.delete(task)
            save()
        }
    }

    private func presentEditor(_ task: TaskItem? = nil) {
        editorMode = task.map(TaskEditorMode.edit) ?? .create
    }

    private func save() {
        do { try modelContext.save() } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}

struct TaskRow: View {
    let task: TaskItem
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            Button(action: onToggle) {
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(task.status == .completed ? "Mark \(task.title) incomplete" : "Mark \(task.title) complete")

            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .strikethrough(task.status == .completed)
                if let notes = task.notes { Text(notes).font(.callout).foregroundStyle(.secondary).lineLimit(2) }
                if let date = task.reminderAt ?? task.dueAt {
                    Text(date, format: .dateTime.month().day().hour().minute())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Menu {
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Actions for \(task.title)")
        }
        .padding(.vertical, 3)
    }
}

@MainActor
struct TaskEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let task: TaskItem?
    @State private var title: String
    @State private var notes: String
    @State private var hasDueDate: Bool
    @State private var dueAt: Date
    @State private var hasReminder: Bool
    @State private var reminderAt: Date
    @State private var errorMessage: String?

    init(task: TaskItem? = nil) {
        self.task = task
        _title = State(initialValue: task?.title ?? "")
        _notes = State(initialValue: task?.notes ?? "")
        _hasDueDate = State(initialValue: task?.dueAt != nil)
        _dueAt = State(initialValue: task?.dueAt ?? .now)
        _hasReminder = State(initialValue: task?.reminderAt != nil)
        _reminderAt = State(initialValue: task?.reminderAt ?? .now)
    }

    private var input: TaskEditorInput { TaskEditorInput(title: title, notes: notes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(task == nil ? "New Task" : "Edit Task").font(.title2.bold())

            Form {
                TextField("Title", text: $title)
                TextField("Notes", text: $notes, axis: .vertical).lineLimit(3...6)
                Toggle("Due date", isOn: $hasDueDate)
                if hasDueDate { DatePicker("Due", selection: $dueAt) }
                Toggle("Reminder", isOn: $hasReminder)
                if hasReminder { DatePicker("Remind me", selection: $reminderAt) }
            }
            .formStyle(.grouped)

            if let errorMessage { Text(errorMessage).foregroundStyle(.red).font(.callout) }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.validatedTitle == nil)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        guard let title = input.validatedTitle else { return }
        let item = task ?? TaskItem(title: title)
        item.title = title
        item.notes = input.normalizedNotes
        item.dueAt = hasDueDate ? dueAt : nil
        item.reminderAt = hasReminder ? reminderAt : nil
        if task == nil { modelContext.insert(item) }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
