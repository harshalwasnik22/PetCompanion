import Foundation
import SwiftData

/// Opens the SwiftData store.
///
/// Opening is allowed to fail and must never respond by deleting or recreating
/// the database — the caller shows recovery information and the original store
/// stays untouched for diagnosis.
enum AppModelContainer {
    static let schema = Schema([TaskItem.self, Habit.self, HabitLog.self])

    /// ponytail: no `VersionedSchema` or migration plan yet. SwiftData's automatic
    /// lightweight migration already covers additive changes, which is all the MVP
    /// has. Add a migration plan before the first non-lightweight change (Plan §6).
    static func make(inMemory: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        return try ModelContainer(for: schema, configurations: configuration)
    }

    /// The on-disk location, so a recovery message can point the user at the file
    /// that failed to open. SwiftData defaults this to Application Support.
    static var storeURL: URL {
        ModelConfiguration(schema: schema, isStoredInMemoryOnly: false).url
    }
}
