import SwiftData
import SwiftUI

@MainActor
struct HabitListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PetReactionEngine.self) private var reactionEngine
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @State private var isPresentingEditor = false
    @State private var errorMessage: String?

    private var activeHabits: [Habit] { HabitListOrdering.active(habits) }
    private var inactiveHabits: [Habit] { HabitListOrdering.inactive(habits) }
    private var habitManager: HabitManager {
        HabitManager(modelContext: modelContext, reactionEngine: reactionEngine)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Today").font(.title2.bold())
                    Text("^[\(activeHabits.count) active habit](inflect: true)")
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
                            HabitRow(habit: habit) { setActive(habit, on: false) }
                        }
                    }

                    Section("Inactive") {
                        if inactiveHabits.isEmpty {
                            Text("No inactive habits").foregroundStyle(.secondary)
                        }
                        ForEach(inactiveHabits) { habit in
                            HabitRow(habit: habit) { setActive(habit, on: true) }
                        }
                    }
                }
            }
        }
        .frame(minWidth: 480, minHeight: 360)
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
}

struct HabitRow: View {
    let habit: Habit
    let onSetActive: () -> Void

    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "circle")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(true)
            .accessibilityLabel("Mark \(habit.name) complete")

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
