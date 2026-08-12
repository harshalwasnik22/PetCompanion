import Foundation
import SwiftData
import Testing
@testable import PetCompanion

@MainActor
@Test func creatingADailyHabitPersistsForAFreshContext() throws {
    let container = try AppModelContainer.make(inMemory: true)
    let manager = HabitManager(
        modelContext: ModelContext(container),
        reactionEngine: PetReactionEngine()
    )

    try manager.create(name: "  Take a walk  ")

    let freshContext = ModelContext(container)
    let habit = try #require(freshContext.fetch(FetchDescriptor<Habit>()).first)
    #expect(habit.name == "Take a walk")
    #expect(habit.frequency == .daily)
    #expect(habit.active)
}

@Test func todayProgressCountsOnlyActiveDailyHabits() {
    let first = Habit(name: "Walk", createdAt: Date(timeIntervalSince1970: 1))
    let inactive = Habit(name: "Read", createdAt: Date(timeIntervalSince1970: 2), active: false)
    let second = Habit(name: "Stretch", createdAt: Date(timeIntervalSince1970: 3))

    #expect(HabitListOrdering.active([second, inactive, first]).map(\.name) == ["Walk", "Stretch"])
}

@MainActor
@Test func deactivatingAHabitRetainsItsHistory() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let habit = Habit(name: "Read")
    context.insert(habit)
    context.insert(HabitLog(habitID: habit.id, dayKey: "2026-08-12"))
    try context.save()
    let manager = HabitManager(modelContext: context, reactionEngine: PetReactionEngine())

    try manager.setActive(habit, on: false)

    #expect(!habit.active)
    #expect(try context.fetchCount(FetchDescriptor<HabitLog>()) == 1)
}

@MainActor
@Test func blankHabitNamesAreRejectedWithoutInserting() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let manager = HabitManager(modelContext: context, reactionEngine: PetReactionEngine())

    #expect(throws: HabitManager.Error.invalidName) {
        try manager.create(name: "")
    }
    #expect(throws: HabitManager.Error.invalidName) {
        try manager.create(name: "   \n")
    }
    #expect(try context.fetchCount(FetchDescriptor<Habit>()) == 0)
}
