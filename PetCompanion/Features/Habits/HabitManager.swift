import Foundation
import SwiftData

@MainActor
final class HabitManager {
    enum Error: LocalizedError {
        case invalidName

        var errorDescription: String? {
            switch self {
            case .invalidName: "Enter a habit name."
            }
        }
    }

    private let modelContext: ModelContext
    private let reactionEngine: PetReactionEngine

    init(modelContext: ModelContext, reactionEngine: PetReactionEngine) {
        self.modelContext = modelContext
        self.reactionEngine = reactionEngine
    }

    func create(name: String) throws {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw Error.invalidName }

        modelContext.insert(Habit(name: name))
        try save()
    }

    func setActive(_ habit: Habit, on active: Bool) throws {
        habit.active = active
        try save()
    }

    /// Returns whether a log was newly created. The caller-visible celebration
    /// hangs off this: the existing-log check is the control flow, and `#Unique`
    /// stays underneath as the database safety net rather than the mechanism.
    @discardableResult
    func completeToday(_ habit: Habit, now: Date = .now) throws -> Bool {
        guard try todayLog(for: habit, now: now) == nil else { return false }

        modelContext.insert(HabitLog(habitID: habit.id, dayKey: HabitLog.dayKey(for: now), completedAt: now))
        try save()
        reactionEngine.show(event: .onHabitCompleted)
        return true
    }

    /// Silent by design: undo is a correction, not an achievement.
    func undoToday(_ habit: Habit, now: Date = .now) throws {
        guard let log = try todayLog(for: habit, now: now) else { return }

        modelContext.delete(log)
        try save()
    }

    private func todayLog(for habit: Habit, now: Date) throws -> HabitLog? {
        // Bound outside the predicate: `#Predicate` cannot reach into the model.
        let habitID = habit.id
        let dayKey = HabitLog.dayKey(for: now)
        let descriptor = FetchDescriptor<HabitLog>(predicate: #Predicate {
            $0.habitID == habitID && $0.dayKey == dayKey
        })
        return try modelContext.fetch(descriptor).first
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

enum HabitListOrdering {
    static func active(_ habits: [Habit]) -> [Habit] {
        // #Predicate cannot compare the stored HabitFrequency enum, so this
        // small list is filtered in Swift.
        habits
            .filter { $0.active && $0.frequency == .daily }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func inactive(_ habits: [Habit]) -> [Habit] {
        habits.filter { !$0.active }.sorted { $0.createdAt < $1.createdAt }
    }
}
