import Foundation
import SwiftData
import Testing
@testable import PetCompanion

@Test func inMemoryContainerOpensAndRoundTripsATask() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    context.insert(TaskItem(title: "Write the plan"))
    try context.save()

    let stored = try context.fetch(FetchDescriptor<TaskItem>())
    #expect(stored.count == 1)
    #expect(stored.first?.status == .pending)
    #expect(stored.first?.completedAt == nil)
}

/// Uses a temporary URL rather than `make(inMemory: false)` so running tests
/// never touches the real Application Support store.
@Test func persistentContainerOpensTheSchemaOnDisk() throws {
    let url = URL.temporaryDirectory.appending(path: "petcompanion-\(UUID().uuidString).store")
    defer { try? FileManager.default.removeItem(at: url) }

    let configuration = ModelConfiguration(schema: AppModelContainer.schema, url: url)
    let container = try ModelContainer(for: AppModelContainer.schema, configurations: configuration)

    let context = ModelContext(container)
    context.insert(Habit(name: "Stretch"))
    try context.save()

    #expect(FileManager.default.fileExists(atPath: url.path(percentEncoded: false)))
    #expect(try context.fetchCount(FetchDescriptor<Habit>()) == 1)
}

@Test func duplicateHabitLogForOneDayCollapsesToASingleRow() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let habitID = UUID()
    let today = HabitLog.dayKey(for: .now)

    context.insert(HabitLog(habitID: habitID, dayKey: today))
    try context.save()
    context.insert(HabitLog(habitID: habitID, dayKey: today))
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<HabitLog>()) == 1)
}

@Test func separateDaysAndSeparateHabitsEachKeepTheirOwnLog() throws {
    let context = ModelContext(try AppModelContainer.make(inMemory: true))
    let habitID = UUID()

    context.insert(HabitLog(habitID: habitID, dayKey: "2026-08-09"))
    context.insert(HabitLog(habitID: habitID, dayKey: "2026-08-10"))
    context.insert(HabitLog(habitID: UUID(), dayKey: "2026-08-10"))
    try context.save()

    #expect(try context.fetchCount(FetchDescriptor<HabitLog>()) == 3)
}
