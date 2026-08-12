import SwiftData
import SwiftUI

@MainActor
struct HabitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PetReactionEngine.self) private var reactionEngine
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query private var logs: [HabitLog]
    @State private var isPresentingEditor = false
    @State private var errorMessage: String?
    /// Neither `@Query` changes when the clock rolls past local midnight, so
    /// without this the window would keep showing yesterday's checkmarks for as
    /// long as it stayed open. `NSCalendarDayChanged` also covers a time-zone
    /// change, which can move "today" in either direction.
    @State private var today = HabitLog.dayKey(for: .now)

    private var activeHabits: [Habit] { HabitListOrdering.active(habits) }
    private var inactiveHabits: [Habit] { HabitListOrdering.inactive(habits) }
    /// ponytail: scans every log to find today's. A personal habit list stays
    /// small for years; add a `dayKey` predicate to the `@Query` if it ever
    /// doesn't, remembering the key has to change at local midnight.
    private var completedHabitIDs: Set<UUID> {
        Set(logs.lazy.filter { $0.dayKey == today }.map(\.habitID))
    }
    private var habitManager: HabitManager {
        HabitManager(modelContext: modelContext, reactionEngine: reactionEngine)
    }

    var body: some View {
        // Bound once per render: the set is derived from every log, and reading
        // the computed property per row would rebuild it that many times.
        let completedHabitIDs = completedHabitIDs

        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Today").font(.title2.bold())
                    Text("\(activeHabits.count { completedHabitIDs.contains($0.id) }) of \(activeHabits.count) complete")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Add Habit", systemImage: "plus") { isPresentingEditor = true }
                    .keyboardShortcut("n")
            }
            .padding()

            Divider()

            if habits.isEmpty {
                ContentUnavailableView {
                    Label("No Habits", systemImage: "repeat")
                } description: {
                    Text("Add a daily habit to get started.")
                } actions: {
                    Button("Add Habit") { isPresentingEditor = true }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("Today") {
                        if activeHabits.isEmpty {
                            Text("Nothing active").foregroundStyle(.secondary)
                        }
                        ForEach(activeHabits) { habit in
                            HabitRow(
                                habit: habit,
                                isCompleted: completedHabitIDs.contains(habit.id),
                                onToggleCompletion: { toggleCompletion(habit) },
                                onSetActive: { setActive(habit, on: false) }
                            )
                        }
                    }

                    Section("Inactive") {
                        if inactiveHabits.isEmpty {
                            Text("No inactive habits").foregroundStyle(.secondary)
                        }
                        ForEach(inactiveHabits) { habit in
                            // No completion here: an inactive habit has left
                            // Today, so checking it off would contradict that.
                            HabitRow(
                                habit: habit,
                                isCompleted: completedHabitIDs.contains(habit.id),
                                onToggleCompletion: nil,
                                onSetActive: { setActive(habit, on: true) }
                            )
                        }
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            today = HabitLog.dayKey(for: .now)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            today = HabitLog.dayKey(for: .now)
        }
        .sheet(isPresented: $isPresentingEditor) {
            HabitEditorSheet()
        }
        .alert("Habit could not be saved", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Unknown error")
        }
    }

    private func setActive(_ habit: Habit, on active: Bool) {
        do {
            try habitManager.setActive(habit, on: active)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleCompletion(_ habit: Habit) {
        do {
            if completedHabitIDs.contains(habit.id) {
                try habitManager.undoToday(habit)
            } else {
                try habitManager.completeToday(habit)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct HabitRow: View {
    let habit: Habit
    let isCompleted: Bool
    /// `nil` for a habit that is not in Today and so cannot be completed.
    let onToggleCompletion: (() -> Void)?
    let onSetActive: () -> Void

    var body: some View {
        HStack {
            Button(action: { onToggleCompletion?() }) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(onToggleCompletion == nil)
            .accessibilityLabel(
                isCompleted ? "Undo completion for \(habit.name)" : "Mark \(habit.name) complete"
            )

            Text(habit.name)
            Spacer()
            Button(habit.active ? "Deactivate" : "Activate", action: onSetActive)
                .buttonStyle(.borderless)
                .accessibilityLabel("\(habit.active ? "Deactivate" : "Activate") \(habit.name)")
        }
        .padding(.vertical, 3)
    }
}

@MainActor
struct HabitEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PetReactionEngine.self) private var reactionEngine
    @State private var name = ""
    @State private var errorMessage: String?

    private var habitManager: HabitManager {
        HabitManager(modelContext: modelContext, reactionEngine: reactionEngine)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Habit").font(.title2.bold())

            Form {
                TextField("Habit name", text: $name)
            }
            .formStyle(.grouped)

            if let errorMessage {
                Text(errorMessage).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func save() {
        do {
            try habitManager.create(name: name)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
