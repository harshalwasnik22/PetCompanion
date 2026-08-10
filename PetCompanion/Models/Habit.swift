import Foundation
import SwiftData

enum HabitFrequency: String, Codable, Sendable {
    case daily
}

@Model
final class Habit {
    var id: UUID
    var name: String
    var frequency: HabitFrequency
    var createdAt: Date
    /// Inactive habits leave the Today list but keep their history.
    var active: Bool

    init(
        id: UUID = UUID(),
        name: String,
        frequency: HabitFrequency = .daily,
        createdAt: Date = .now,
        active: Bool = true
    ) {
        self.id = id
        self.name = name
        self.frequency = frequency
        self.createdAt = createdAt
        self.active = active
    }
}
