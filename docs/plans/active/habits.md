# Daily habits: model, UI, and unique completion

Covers issues #16 (habit model and UI) and #17 (unique completion and undo).
They are one feature split across two issues; #17 depends on #16.

## Problem and goal

`Habit` and `HabitLog` already exist from #7, with `HabitLog.dayKey(for:timeZone:)`
and the `#Unique<HabitLog>([\.habitID, \.dayKey])` constraint. Nothing creates or
displays them: the Habits window is still `PlaceholderDestinationView`.

Goal: a user can create a named daily habit, see it in Today with a progress
count, check it off exactly once per local day, undo that, and deactivate a habit
without losing its history.

## Non-goals

- Frequencies other than `.daily`. `HabitFrequency` has one case and stays that way.
- Streak counts, statistics, or history views. Only today's state is displayed.
- Habit reminders or notifications. Habits do not schedule anything.
- Renaming or merging habits by name. Duplicate names are allowed as labels.

## Assumptions

- The Habits window gets the same `backedByStore` treatment as Tasks, so
  `HabitListView` reads `@Query` and takes its `ModelContext` from the environment.
- `PetReactionEngine.onHabitCompleted` already exists (happy, "Streak secured!",
  3s, priority 75). No engine change is needed.
- Undo is a deliberate user action and stays silent — no reaction, per §3H.

## Current behavior and constraints

- `Habit`: `id`, `name`, `frequency`, `createdAt`, `active`.
- `HabitLog`: `id`, `habitID`, `dayKey`, `completedAt`, unique on `(habitID, dayKey)`.
- `HabitLog.dayKey` is a fixed Gregorian calendar in the user's current time zone,
  `yyyy-MM-dd`. It is the definition of "today" — never a rolling 24 hours.
- `TaskManager` is the pattern to follow: `@MainActor final class`, injected
  `ModelContext` and `PetReactionEngine`, a private `save()` that rolls back and
  rethrows, and a `LocalizedError` enum for validation failures.
- `#Predicate` cannot compare a stored enum. Filter such cases in Swift.

## Design

`HabitManager` (`PetCompanion/Features/Habits/HabitManager.swift`) owns all
mutation. Views own no business logic.

```
create(name:) throws           -> rejects blank/whitespace-only names
setActive(_:on:) throws        -> leaves logs untouched
completeToday(_:now:) throws   -> @discardableResult Bool, true only when newly created
undoToday(_:now:) throws       -> deletes only today's log, fires no reaction
```

`completeToday` fetches an existing `(habitID, dayKey)` log first and returns
`false` when one exists, so the celebration fires only on a genuinely new
completion. `#Unique` stays underneath as the database safety net, not as the
control flow — a constraint violation is a bug, not an expected path.

`HabitViews.swift` holds `HabitListView`, the Today progress header, `HabitRow`,
`HabitEditorSheet`, the empty state, and the inactive-habit area, mirroring how
`TaskViews.swift` groups the Tasks UI in one file.

## Tasks

**T1 — #16, habit model and UI.** Owns:
- `PetCompanion/Features/Habits/HabitManager.swift` (new): `create`, `setActive`.
- `PetCompanion/Features/Habits/HabitViews.swift` (new): list, header, row,
  editor sheet, empty state, inactive area.
- `PetCompanion/App/PetCompanionApp.swift`: swap the Habits placeholder for
  `HabitListView`.
- `PetCompanionTests/HabitManagerTests.swift` (new).

`HabitRow`'s check control must be a real `Toggle`/`Button` with an accessibility
label naming the habit — not a tap-only image.

Today shows active habits only; inactive habits appear in their own area and keep
their logs.

**T2 — #17, unique completion and undo.** Depends on T1. Owns:
- `HabitManager.swift`: add `completeToday`, `undoToday`.
- `HabitViews.swift`: wire the row's check and undo.
- `HabitManagerTests.swift`, and day-key coverage in
  `PetCompanionTests/HabitDayKeyTests.swift`.

## Acceptance criteria and evidence

| Criterion | Issue | Evidence |
| --- | --- | --- |
| New daily habit appears in Today and survives restart | #16 | Test: create, re-fetch from a fresh context on the same container |
| Today progress reflects active habits only | #16 | Test: progress with a mix of active and inactive |
| Inactive habits leave Today but retain history | #16 | Test: deactivate a habit with a log, assert the log still exists |
| Blank names rejected | #16 | Test: `""` and `"   "` both throw and insert nothing |
| Exactly one log per habit per local day | #17 | Test: two `completeToday` calls, one log |
| Repeated completion idempotent, no replayed celebration | #17 | Test: second call returns `false` and fires no reaction |
| Undo removes only today's log, no reaction | #17 | Test: yesterday's log survives, reaction unchanged |
| Day key across DST, local midnight, time-zone change | #17 | Tests in `HabitDayKeyTests.swift` |

## Risks

- Reaction-on-completion must key off the returned `Bool`, not the call. Firing in
  the view on every tap reintroduces the replayed celebration #17 exists to prevent.
- `@Query` sort order must be stable (`createdAt`) or rows reorder as the user types.
- Deleting a `Habit` is out of scope; deactivation is the supported path. Do not
  add cascade rules for logs.

## Verification

`xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS'`

There is no iOS simulator destination for this project; macOS is the only one.
