import Foundation
import SwiftData

/// One completion of one habit on one local calendar day.
///
/// `dayKey` exists instead of a `Date` because "today" is a calendar day in the
/// user's time zone, not a rolling 24 hours — a DST day is 23 or 25 hours long
/// and date arithmetic gets that wrong. Storing the resolved key also lets the
/// database enforce one-completion-per-day directly.
@Model
final class HabitLog {
    #Unique<HabitLog>([\.habitID, \.dayKey])

    var id: UUID
    var habitID: UUID
    var dayKey: String
    var completedAt: Date

    init(id: UUID = UUID(), habitID: UUID, dayKey: String, completedAt: Date = .now) {
        self.id = id
        self.habitID = habitID
        self.dayKey = dayKey
        self.completedAt = completedAt
    }

    /// Stable `yyyy-MM-dd` identity for the local day containing `date`.
    ///
    /// ponytail: fixed Gregorian calendar with the user's current time zone. Day
    /// boundaries follow the time zone, which is what "today" means for nearly
    /// everyone; switch to `Calendar.current` if a non-Gregorian calendar user
    /// ever needs their own day boundaries. Doing that now would make the key
    /// change whenever the user changes calendar preference, which would let a
    /// second log slip in for the same day.
    static func dayKey(for date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }
}
