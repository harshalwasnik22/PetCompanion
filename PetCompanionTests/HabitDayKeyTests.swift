import Foundation
import Testing
@testable import PetCompanion

private let newYork = TimeZone(identifier: "America/New_York")!
private let kolkata = TimeZone(identifier: "Asia/Kolkata")!

private func date(
    _ year: Int, _ month: Int, _ day: Int,
    _ hour: Int, _ minute: Int,
    in timeZone: TimeZone
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    return calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    )!
}

@Test func lateEveningStaysOnTheLocalDayNotTheUTCDay() {
    // 23:30 in New York is already the next day in UTC. The key must follow the
    // user's day, or a habit completed before bed lands on tomorrow.
    let evening = date(2026, 8, 9, 23, 30, in: newYork)

    #expect(HabitLog.dayKey(for: evening, timeZone: newYork) == "2026-08-09")
    #expect(HabitLog.dayKey(for: evening, timeZone: .gmt) == "2026-08-10")
}

@Test func earlyMorningStaysOnTheLocalDayForAheadOfUTCZones() {
    // 00:30 in Kolkata (UTC+5:30) is still the previous day in UTC.
    let earlyMorning = date(2026, 8, 10, 0, 30, in: kolkata)

    #expect(HabitLog.dayKey(for: earlyMorning, timeZone: kolkata) == "2026-08-10")
    #expect(HabitLog.dayKey(for: earlyMorning, timeZone: .gmt) == "2026-08-09")
}

@Test func springForwardDayIsOneKeyDespiteBeingTwentyThreeHoursLong() {
    // US DST starts 2026-03-08; that local day has 23 hours. Anything built on
    // 24-hour arithmetic drifts here, which is why the key is calendar-derived.
    let justAfterMidnight = date(2026, 3, 8, 0, 30, in: newYork)
    let lateEvening = date(2026, 3, 8, 23, 30, in: newYork)

    #expect(HabitLog.dayKey(for: justAfterMidnight, timeZone: newYork) == "2026-03-08")
    #expect(HabitLog.dayKey(for: lateEvening, timeZone: newYork) == "2026-03-08")
}

@Test func fallBackDayIsOneKeyDespiteBeingTwentyFiveHoursLong() {
    // US DST ends 2026-11-01; 01:30 happens twice that day.
    let firstOneThirty = date(2026, 11, 1, 1, 30, in: newYork)
    let lateEvening = date(2026, 11, 1, 23, 30, in: newYork)

    #expect(HabitLog.dayKey(for: firstOneThirty, timeZone: newYork) == "2026-11-01")
    #expect(HabitLog.dayKey(for: lateEvening, timeZone: newYork) == "2026-11-01")
}

@Test func singleDigitMonthsAndDaysArePadded() {
    #expect(HabitLog.dayKey(for: date(2026, 1, 5, 12, 0, in: .gmt), timeZone: .gmt) == "2026-01-05")
}
