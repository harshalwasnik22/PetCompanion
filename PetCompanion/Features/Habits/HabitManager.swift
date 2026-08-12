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
