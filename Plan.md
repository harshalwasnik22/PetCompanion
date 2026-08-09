# Pet Companion for macOS — MVP Product and Engineering Plan

**Product target:** macOS 15+ · one red panda · local-first · development-Mac release

## 1. Product vision

Pet Companion is a small personal productivity utility for Mac users who want a warmer alternative to a conventional checklist. A cute red panda lives in a small desktop overlay, accepts quick tasks, reacts when work is completed, celebrates daily habits, and gently surfaces reminders. It is for students, developers, remote workers, and anyone who benefits from an ambient companion: the pet makes progress emotionally engaging without becoming a game, an assistant, or a source of interruption.

## 2. MVP scope

### Included

- One draggable red panda in a transparent, always-on-top desktop overlay.
- A menu-bar-first macOS utility with tasks, habits, quick capture, settings, and quit controls.
- Local task creation, viewing, completion, deletion, optional notes, optional due date, and one optional reminder.
- macOS local reminder notifications, including Open Task and Mark Complete notification actions.
- Task-only Quick Capture from the pet, menu bar, and a fixed global hotkey.
- Daily habits with a Today view and one completion per habit per local day.
- Basic pet states, speech bubbles, optional sound, and idle/sleepy behavior.
- SwiftData persistence and `UserDefaults` preferences that restore after restart.
- Accessibility labels, motion reduction, multi-monitor clamping, and a launch-at-login toggle.

### Explicitly excluded

- Cloud sync, accounts, multiple users, sharing, collaboration, and mobile apps.
- AI assistant features, AI task breakdown, RAG over notes, local LLMs, and knowledge graphs.
- Calendar sync, email ingestion, link/file capture, attachments, search, tags, and analytics.
- Standalone notes: Quick Capture stores tasks only so user input never enters a write-only data store.
- Multiple selectable pets in the shipped UI, accessories, skins, pet bond/XP, currency, or complex gamification.
- Advanced recurrence, advanced habit schedules, automatic updates, Developer ID signing, notarization, and Mac App Store release work.

### Product guardrails

- The pet is ambient. It must never force focus, open windows unexpectedly, or block normal work.
- All data works locally without a network connection.
- The MVP uses only direct, native abstractions. One interface with one implementation is a concrete class, not a protocol layer.
- Development builds are supported on the development Mac through Xcode local signing. Copying an unsigned build to another Mac is not a supported notification-distribution path.

## 3. Feature breakdown

### A. Desktop pet overlay

**User goal.** Keep a friendly companion visible while working without disturbing ordinary apps.

**User experience.** On launch, a red panda appears at a safe lower-right position on the primary display. The user drags it by its body; the pet follows and settles within the usable part of the screen. A click shows a short greeting. It uses a quiet idle animation and clear visual states while reacting. The app remembers its valid position and visibility after restart.

**Core UI components.** A transparent, borderless `NSPanel` hosts `PetOverlayView`, containing the pet image, an optional pointer-free speech bubble, and a drag hit area. The first implementation uses self-made or licensed placeholder frames named by state, for example `redpanda-idle` and `redpanda-happy`; final art can replace them without code changes.

**Local logic.** `PetOverlayManager` owns an `NSPanel` with floating level, clear background, no title bar, and custom dragging. It saves position, visibility, and display identifier directly through `UserDefaults`.

The panel is a fixed 320 × 260 points and never resizes. The 144 × 144 pet is anchored bottom-center inside it; the remaining transparent margin is headroom for the speech bubble, which can therefore appear and disappear without moving or resizing the window. All geometry—saved position, drag math, and clamping—uses the **pet's rect within the panel**, not the panel frame. At drag end and launch, the manager clamps so at least 48 points of the pet rect stay inside the chosen `NSScreen.visibleFrame`; clamping the panel frame instead would allow a fully invisible pet behind 48 points of transparent margin. If the stored display is missing, it uses the primary display. `LSUIElement = YES` makes the utility an agent app without a Dock icon; regular task/habit windows explicitly activate when opened. Apple documents `LSUIElement` as the agent-app Info.plist key: [LSUIElement](https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement).

**Edge cases.** A changed resolution or disconnected display produces a clamped primary-display position. Full-screen apps hide the pet by default; Settings can opt into full-screen visibility. During a drag, lower-priority pet reactions do not replace the dragged pose. If Reduce Motion is enabled, do not start frame animation—use the state’s still image instead.

**Acceptance criteria.**

- The overlay sits above ordinary windows without stealing focus.
- The pet remains at least partly visible on one connected display after dragging or restart.
- Visibility and a valid last position survive restart.
- Idle, happy, dragged, and hidden states are distinguishable.
- By default, the pet is not shown over full-screen apps.

### B. Task creation and completion

**User goal.** Record work quickly and receive satisfying acknowledgement when it is finished.

**User experience.** The user adds a task from the menu bar, Quick Capture, or the Tasks window. The Tasks window groups Pending and Completed tasks. Completing a task moves it to Completed immediately and makes the red panda react; a row menu offers Delete.

**Core UI components.** `TaskListView`, `TaskRow`, `TaskEditorSheet`, empty state, Pending/Completed sections, and an inline Add Task button. The editor includes title, optional notes, optional due date, optional reminder, Save, and Cancel.

**Local logic.** Views use `@Query` for reactive task lists and read `@Environment(\.modelContext)` for mutations. `TaskManager` validates a trimmed non-empty title, inserts/updates/deletes the SwiftData model, schedules/cancels task notifications, and emits pet events only after the save succeeds. Pending tasks sort by reminder/due date then creation time; completed tasks sort by `completedAt` descending. No repository or persistence protocol sits between the manager and SwiftData.

**Edge cases.** Whitespace-only titles cannot be saved. Tasks without dates remain valid. Editing a completed task does not reopen it. If a save fails, the UI reports a non-blocking error and does not play a success reaction.

**Acceptance criteria.**

- Valid tasks created from every entry point appear in Pending and survive restart.
- Completion sets `status` and `completedAt`, moves the task to Completed, cancels its reminder, and triggers one reaction.
- Delete removes the task and its pending notification request.
- Invalid titles cannot be saved.

### C. Reminder notifications

**User goal.** Receive a reminder about a task at a chosen time, even away from the task list.

**User experience.** In the task editor, the user enables Reminder and chooses a future time. At first use, the app explains the request in context and asks for notification permission. At delivery time, macOS presents a local notification; while the app is running, the pet also uses a reminder bubble.

**Core UI components.** Reminder toggle/date picker in the task editor, permission status explanation, and a Settings link when permission is denied. Notification categories provide Open Task and Mark Complete actions.

**Local logic.** `ReminderScheduler` derives `task-reminder-<task UUID>` and uses a non-repeating `UNCalendarNotificationTrigger`. Changing a reminder calls `add` with the same identifier; macOS replaces the pending request with that identifier. Completing/deleting cancels it. On each launch, loop over future incomplete task reminders and call `add` again—an idempotent, short self-healing operation that also handles permissions granted after an earlier denial. Apple documents identifier replacement behavior: [UNNotificationRequest identifier](https://developer.apple.com/documentation/usernotifications/unnotificationrequest/identifier).

**Edge cases.** A past time cannot be saved. A denied/restricted permission leaves `reminderAt` stored but reports that no visible alert is available. Focus, sleep, alert settings, and system policy can delay or suppress delivery. Multiple simultaneous reminders stay separate system requests but become one summarized pet bubble such as “You have 3 reminders.”

**Acceptance criteria.**

- Each future task reminder has one deterministic local notification request.
- Editing, completing, deleting, and restart rescheduling are idempotent.
- Permission denial does not crash or lose reminder data.
- A foreground reminder triggers the high-priority pet reminder state.

### D. Quick Capture sticky note

**User goal.** Capture a task without navigating the full task-management window.

**User experience.** The user opens Quick Capture from the pet, menu bar, or one fixed global shortcut: Command-Option-P. A small focused sticky card appears beside the pet, or on the screen containing the pointer when the pet is hidden. The user writes a task, optionally expands task notes/reminder fields, then saves or cancels. The card disappears after submission or cancellation.

**Core UI components.** `QuickCapturePanel`, title field, optional expandable notes/reminder controls, Save, and Cancel. Task capture is the only mode; there is no type switch or standalone note model.

**Local logic.** `QuickCaptureController` places the panel near the pet and clamps it to the visible frame. It sends successful submissions through `TaskManager`. A fixed `RegisterEventHotKey` registration provides the global shortcut. If the shortcut cannot be registered, present a concise Settings status message; pet and menu-bar entry points remain available. Do not build a hotkey recorder or shortcut preference in the MVP.

**Edge cases.** Escape discards unsaved text. Return saves from a single-line title field; Command-Return saves when the expanded notes editor has focus. Empty input cannot submit. A missing target monitor sends the panel to the primary display.

**Acceptance criteria.**

- Quick Capture opens focused from pet, menu bar, and the fixed hotkey.
- Save creates a pending task and triggers task-added feedback.
- Cancel makes no data change.
- Capture always stays within the visible screen frame.

### E. Basic pet reactions

**User goal.** Receive brief emotional feedback that makes progress feel rewarding.

**User experience.** The pet changes pose and can show one short speech bubble after meaningful actions. It returns to idle, becoming sleepy after a long quiet period. Reactions never block task or habit interactions.

**Core UI components.** `PetView`, `SpeechBubbleView`, named placeholder/final asset mapping, and optional short local sound player.

**Local logic.** `PetReactionEngine` is one concrete `@Observable` class holding `mood`, `bubble`, `priority`, and one cancellable `Task` that resets the display after a duration. `show(event:)` maps an event to a state; a higher-priority event interrupts a lower-priority event. A new equal-priority action simply replaces and restarts the current short reaction. There is no FIFO queue, event coalescing scheduler, injected clock, or provider protocol. Idle/sleepy is a timer-derived state.

**Edge cases.** Never stack bubbles. If hidden, discard transient visual reactions and resume idle when shown. Throttle click greetings to one every two seconds. Sound disabled/unavailable never suppresses visual feedback. Reduce Motion stops animation but keeps the static pose and bubble.

**Acceptance criteria.**

- Supported events produce their mapped presentation immediately after successful work.
- Transient reactions reset to idle automatically.
- A reminder interrupts lower-priority click/task-added feedback.
- A second task completion while the first is visible refreshes the short celebration rather than creating a queue.

### F. Local storage

**User goal.** Trust that tasks, habits, and pet placement survive restart without an account.

**User experience.** The user reopens the app and sees their task/habit state normally. Storage is invisible except for a clear recovery message if the database cannot open.

**Core UI components.** No storage-management screen. Settings can show an error/recovery explanation if model-container startup fails.

**Local logic.** SwiftData directly stores `TaskItem`, `Habit`, and `HabitLog` in the app support directory. SwiftUI views use `@Query` for read reactivity; mutation managers use the environment’s actual `ModelContext`. Tests configure the same models with `ModelConfiguration(isStoredInMemoryOnly: true)`. `UserDefaults` stores pet geometry and app preferences. Every command saves before success feedback.

**Edge cases.** Storage startup failure preserves the original database and presents recovery information; it never silently wipes data. SwiftData migration occurs before productivity UI appears. A write failure produces no completion celebration.

**Acceptance criteria.**

- Tasks, habits, logs, visibility, and valid pet position survive restart.
- In-memory tests exercise the actual SwiftData models.
- Failed mutations cannot falsely appear as saved.

### G. Menu bar controls

**User goal.** Control the utility without a permanent main window or Dock icon.

**User experience.** A red-panda menu-bar icon opens a compact window-style popover with Add Task, Quick Capture, Tasks, Habits, Show/Hide Pet, Pets, Settings, and Quit. Pets shows Red Panda selected and “More pets later” disabled.

**Core UI components.** `MenuBarExtra`, `StatusMenuView`, app commands, and scene/window routing.

**Local logic.** `MenuBarController` routes actions directly to the relevant manager/window and brings an existing task or habit window forward rather than duplicating it. Show/Hide immediately saves the setting. The app is an agent utility through `LSUIElement`; opening normal windows explicitly activates the app for keyboard input.

**Edge cases.** If overlay startup fails, task/habit actions still work and pet-specific actions show an error. Quit saves normal in-memory preference changes and leaves valid macOS-scheduled reminders intact.

**Acceptance criteria.**

- Every required menu item routes correctly.
- Show/Hide updates the overlay immediately and persists.
- Opening an already-open task/habit window focuses it.
- Quit preserves data and future system reminders.

### H. Habit tracking

**User goal.** Maintain a lightweight daily routine list and receive a small celebration for today’s progress.

**User experience.** Habits shows active daily habits with check controls and a Today progress count. The user creates a named daily habit, marks it done, and can undo a mistaken completion. Inactive habits leave Today but retain history.

**Core UI components.** `HabitListView`, Today progress header, `HabitRow`, `HabitEditorSheet`, empty state, and inactive-habit management.

**Local logic.** `HabitManager` creates active `.daily` habits and exposes one `completeToday` command that returns whether a log was newly created. `HabitLog` stores a normalized local `dayKey` and uses a compound SwiftData `#Unique` constraint for `(habitID, dayKey)`. The manager emits a habit reaction only for a newly created completion; uniqueness remains the database safety net. Today derives from the current calendar/day key, not a rolling 24-hour duration. SwiftData supports compound unique constraints through `#Unique`: [SwiftData Unique](https://developer.apple.com/documentation/swiftdata/unique(_:)).

**Edge cases.** Repeated taps are idempotent and do not repeat a celebration. Time-zone/DST changes recalculate Today using the current local calendar. Inactive habits retain their historical logs. Blank names cannot save; duplicate names are allowed labels.

**Acceptance criteria.**

- A daily habit appears in Today and survives restart.
- First completion creates exactly one day log, updates progress, and triggers one reaction.
- Repeated completion is idempotent; undo removes only today’s log.
- Inactive habits do not appear in Today counts.

## 4. Recommended tech stack

### Native Swift/SwiftUI/AppKit

Use Swift 6, SwiftUI, SwiftData, UserNotifications, and targeted AppKit. SwiftUI owns normal task/habit/settings windows and reactive model lists through `@Query`. AppKit supplies the one thing SwiftUI does not model comfortably: a transparent, non-activating, draggable `NSPanel` desktop overlay. `MenuBarExtra` supplies the native menu-bar utility surface, and `SMAppService.mainApp` supplies the launch-at-login implementation.

Strengths: direct macOS integration, small runtime footprint, good accessibility, direct window/notification APIs, no browser runtime, and a strong native portfolio story. Cost: a small amount of AppKit bridging for the panel and global hotkey.

### Electron or Tauri with React

Electron is fast for web developers but brings Chromium/Node overhead and makes desktop overlay, activation policy, menu-bar behavior, and notifications less natural. Tauri reduces runtime size but adds Rust and WebView/tooling complexity without a meaningful benefit for a macOS-only portfolio MVP.

### Recommendation

Use native SwiftUI/AppKit. The differentiators are macOS-specific: a floating panel, menu bar, notification lifecycle, multiple displays, activation policy, and global hotkey behavior. Native APIs solve these with the least code. Apple describes [MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra) as a persistent menu-bar control and [ModelContainer](https://developer.apple.com/documentation/swiftdata/modelcontainer) as the storage container for SwiftData models.

## 5. High-level architecture

```text
SwiftUI views / MenuBarExtra / NSPanel overlay
                  │
                  ▼
@Environment(ModelContext) + concrete @Observable managers
                  │
      ┌───────────┼──────────────────────┐
      ▼           ▼                      ▼
TaskManager  HabitManager      QuickCaptureController
      │           │                      │
      ├── SwiftData ModelContext ◀───────┘
      ├── ReminderScheduler ── UNUserNotificationCenter
      └── PetReactionEngine ── PetOverlayManager ── NSPanel

SettingsManager ── UserDefaults
MenuBarController ── window routing and actions
```

### Module responsibilities

- **App entry point:** creates the shared `ModelContainer`, injects it into scenes, creates long-lived observable managers, configures `LSUIElement`, and registers notification categories at launch. It is not a generic composition-root framework.
- **Pet Overlay Manager:** owns the panel, screen selection, drag geometry, visibility, and bubble placement. It renders presentation state but does not choose reactions.
- **Task Manager:** validates tasks, applies SwiftData mutations, coordinates reminder scheduling, and asks the reaction engine to react after success.
- **Habit Manager:** creates habits and performs idempotent daily completion/undo operations.
- **Reminder Scheduler:** creates/removes deterministic local requests and re-adds all future incomplete reminders at startup.
- **Notification Manager:** requests authorization, handles foreground delivery and notification actions, and routes to the task manager.
- **Quick Capture Controller:** opens/focuses/places the capture panel and submits task input.
- **Menu Bar Controller:** opens existing windows or presents/focuses one as needed; routes menu actions.
- **Settings Manager:** directly reads/writes `UserDefaults`, applies display/sound settings, and registers/unregisters `SMAppService.mainApp` for launch at login.
- **Pet Reaction Engine:** owns the current mood, bubble, priority, and one expiry task.

### Communication rules

- Feature views query SwiftData directly and call the corresponding concrete manager for commands.
- Managers save before showing success feedback.
- Managers call the concrete reaction engine; no event bus is required for this MVP.
- The reaction engine is the only code that maps actions to pet mood/bubble/duration.
- UI and panel controllers are `@MainActor`; no repositories or dependency protocols are introduced.

## 6. Data model

### SwiftData models

| Model | Fields | Rules |
| --- | --- | --- |
| `TaskItem` | `id: UUID`, `title: String`, `notes: String?`, `status: TaskStatus`, `dueAt: Date?`, `reminderAt: Date?`, `createdAt: Date`, `completedAt: Date?` | Trimmed non-empty title. Completion assigns `completedAt`. Notification identifier derives from `id`. |
| `Habit` | `id: UUID`, `name: String`, `frequency: HabitFrequency`, `createdAt: Date`, `active: Bool` | MVP allows `.daily` only. Name must be non-empty; it need not be unique. |
| `HabitLog` | `id: UUID`, `habitID: UUID`, `dayKey: String`, `completedAt: Date` | `dayKey` is local calendar `yyyy-MM-dd`; declare `#Unique<HabitLog>([\.habitID, \.dayKey])`. |

```swift
enum TaskStatus: String, Codable { case pending, completed }
enum HabitFrequency: String, Codable { case daily }
enum PetKind: String, Codable { case redPanda }
enum PetMood { case idle, happy, excited, sleepy, dragged, reminding }
```

The task model is named `TaskItem`, not `Task`. A `@Model final class Task` shadows `_Concurrency.Task` in every file that imports the model, which forces `_Concurrency.Task { … }` at each async call site—including the reaction engine's own expiry task. `PetMood` is runtime-only and needs no `Codable`. `PetKind` exists to name the asset set and is not a user-facing choice; the MVP ships no pet picker.

### Preferences

Store small preferences in `UserDefaults` rather than SwiftData.

| Settings group | Fields | Defaults |
| --- | --- | --- |
| `PetSettings` | `activePet`, `petName`, `positionX`, `positionY`, `displayID`, `isVisible` | `redPanda`, “Momo”, lower-right primary display, visible |
| `AppSettings` | `launchAtLogin`, `soundEnabled`, `showPetInFullScreen` | false, true, false |

Position coordinates use macOS screen coordinates and are revalidated against connected screens at launch. Mood is transient and is never persisted. There is no `Note` entity and no configurable shortcut setting.

Notification authorization is never stored. It lives in System Settings, the user can change it while the app is closed, and a cached copy goes stale silently—the same failure mode that keeps mood out of `UserDefaults`. Read `UNUserNotificationCenter.current().notificationSettings()` when the value is needed. `launchAtLogin` follows the same rule and reads `SMAppService.mainApp.status`; it appears in the table only as the user-facing toggle label.

### Storage and migration policy

- Use one versioned `ModelContainer` with an app-support storage URL and lightweight migration for additive changes.
- Use `ModelConfiguration(isStoredInMemoryOnly: true)` for unit tests against the same models.
- If the store cannot open, preserve it and show recovery information rather than deleting user data.
- No CloudKit capability, server, sync, or network persistence exists in MVP.

## 7. Main user flows

### First launch

1. The app initializes its model container, settings, menu bar item, and overlay.
2. The red panda appears at a safe primary-screen position and displays its natural idle state.
3. No onboarding window or permission prompt appears.
4. The menu bar provides all discoverable actions; notification permission is requested only when the user saves a first reminder.

### Add a task

1. User selects Add Task, opens Quick Capture, or opens the Tasks window.
2. User enters a non-empty title and may add notes, due date, and reminder.
3. Task Manager validates and saves through the real model context.
4. A future reminder is scheduled if valid/authorized.
5. The pending list updates through `@Query`; the pet displays task-added feedback.

### Complete a task

1. User checks a Pending task or chooses Mark Complete from a notification.
2. Task Manager sets completion state/time, saves, and cancels the deterministic reminder request.
3. `@Query` moves the task to Completed.
4. The reaction engine starts the excited state.

### Add a reminder

1. User enables reminder in a task editor and chooses a future date/time.
2. If authorization is undetermined, app explains and requests it.
3. Scheduler calls `add` with `task-reminder-<id>`.
4. UI reports scheduled status or denied/unavailable notification status.

### Reminder fires

1. macOS delivers the local notification subject to its alert/Focus/sleep policy.
2. Notification actions let the user open the task or mark it complete.
3. Foreground delivery calls the reaction engine with the task ID(s).
4. The pet shows the reminding state/bubble, interrupting lower-priority feedback.

### Add and complete a habit

1. User opens Habits, creates a non-empty daily habit, and sees it in Today.
2. User checks the habit.
3. Habit Manager creates the one unique day log and returns `created`.
4. Today progress updates through `@Query`; one happy reaction plays.
5. A later check is idempotent. Undo removes only today’s log.

### Quick capture

1. User clicks the pet, chooses Quick Capture, or presses Command-Option-P.
2. Focused task capture appears near the pet or pointer screen.
3. User enters a title and optionally expands task notes/reminder.
4. Save creates a task; Escape/Cancel discards it.

### Hide/show and restart

1. Show/Hide Pet updates the panel and `PetSettings.isVisible`.
2. On restart, the app restores model data and validates the saved screen placement.
3. It re-adds every future incomplete reminder using its stable identifier.
4. Pet begins idle; no former mood/bubble is restored.

## 8. Pet reaction system

### Event surface

```swift
enum PetEvent {
    case onPetClicked
    case onPetDragged(isDragging: Bool)
    case onTaskAdded
    case onTaskCompleted
    case onReminderDue(count: Int)
    case onHabitCompleted
}
```

Idle and sleepy are not events. They are what the engine shows when no temporary reaction is active, derived from an inactivity timer, so there is no `onIdle` case to send.

### Reaction table

| Event | State | Bubble examples | Duration | Priority |
| --- | --- | --- | ---: | ---: |
| Reminder due | reminding | “Psst—time for your task!”, “You have 3 reminders.” | 6 seconds | 100 |
| Task completed | excited | “You did it!”, “Nice work!” | 3 seconds | 80 |
| Habit completed | happy | “Streak secured!”, “Daily win!” | 3 seconds | 75 |
| Task added | happy | “I’ll remember that!” | 2.5 seconds | 60 |
| Pet dragged | dragged | None | while dragging | 50 |
| Pet clicked | happy | “Hi!”, “Ready when you are.” | 2 seconds | 40 |
| Idle | idle/sleepy | Optional rare “I’m here.” | persistent | 0 |

### Rules

- Display only one state/bubble at a time.
- A higher-priority state interrupts the visible lower-priority state.
- A new equal-priority event replaces the current state and restarts its duration; events are not queued.
- Click greetings are throttled for two seconds.
- Idle starts when no temporary reaction is active; sleepy starts after ten minutes without user/domain activity.
- When Reduce Motion is active, retain the still image and bubble but do not animate frames or movement.

## 9. UI/UX details

### Floating pet and bubble

- Render the pet at 144 × 144 points, anchored bottom-center in the fixed 320 × 260 clear panel, with 2×/3× asset support.
- Use low-cadence idle animation only when Reduce Motion is off.
- Use a cream speech bubble with dark high-contrast text, maximum two lines, drawn inside the panel's margin above the pet, flipping below when the pet sits near the top of the screen.
- VoiceOver label: “Momo the red panda, [current mood]. Double-click for quick capture.”

### Quick Capture

- Use a 300–340 point warm sticky card with title field, optional expanded notes/reminder controls, Save, and Cancel.
- Task title is focused by default. No Task/Note type selector appears.
- Escape cancels; Return saves a simple title; Command-Return saves from expanded multi-line notes.

### Task and Habit windows

- Task window: 480-point minimum width, Add Task/pending count header, Pending and Completed sections, accessible completion controls, and trailing Edit/Delete menu.
- Habit window: Today header and progress count, active daily habit checks, inactive management area, and simple empty state.
- Both use standard resizable SwiftUI windows and system typography/controls.

### Menu bar and Settings

- The window-style `MenuBarExtra` puts Add Task, Quick Capture, Tasks, Habits, and Show/Hide first; Settings and Quit follow a divider.
- Settings uses General (launch at login), Pet (name and full-screen policy), Notifications (authorization/sound), and About/diagnostics. No Shortcuts tab exists.
- Launch at login reflects real `SMAppService.mainApp.status`, registers/unregisters on change, and reports failure. Apple documents `mainApp` as the service for launching the main application at login: [SMAppService.mainApp](https://developer.apple.com/documentation/servicemanagement/smappservice/mainapp).

## 10. Implementation milestones

### Milestone 1 — Utility shell and pet overlay

**Goal:** Validate the app’s risky macOS-specific behavior first.

**Tasks:** Create macOS 15 SwiftUI target; set `LSUIElement`; add `MenuBarExtra`/window routing; create the transparent `NSPanel`; use placeholder red-panda still/idle frames; implement dragging, screen clamping, show/hide, and direct `UserDefaults` geometry persistence.

**Expected output:** A Dock-less menu-bar app has a clickable/dragged pet overlay that restores a valid position across relaunch.

**Dependencies:** None.

### Milestone 2 — Tasks, local storage, and reactions

**Goal:** Deliver a useful persistent task app connected to the pet.

**Tasks:** Define SwiftData `TaskItem` model/container; build task list/editor with `@Query`; write `TaskManager`; add create/complete/delete; build simple concrete reaction engine and speech bubble; test all task/domain logic with in-memory SwiftData.

**Expected output:** Persistent task CRUD and immediate task-added/task-completed feedback.

**Dependencies:** Milestone 1.

### Milestone 3 — Reminders and notifications

**Goal:** Add reliable local reminder behavior.

**Tasks:** Add task reminder UI/validation; request authorization in context; register notification categories/actions; schedule/cancel deterministic requests; re-add future reminders at launch; handle foreground delivery; add reminder reaction.

**Expected output:** Valid task reminders produce local notifications on the development Mac and pet feedback while active.

**Dependencies:** Milestone 2.

### Milestone 4 — Daily habits

**Goal:** Add the second core productivity loop without a generic habit engine.

**Tasks:** Define `Habit`/`HabitLog` with compound uniqueness; build Today habit UI/editor; implement completion/undo/inactive behavior and happiness response; unit-test day-key/DST behavior.

**Expected output:** Daily habits are persistent, idempotently completable, and emotionally acknowledged.

**Dependencies:** Milestone 2.

### Milestone 5 — Quick Capture, settings, and local release validation

**Goal:** Make the product effortless to use and ready for a portfolio demonstration.

**Tasks:** Build task-only Quick Capture and fixed global hotkey; add launch-at-login using `SMAppService`; finish notification/pet/accessibility settings; apply Reduce Motion/sound rules; complete manual regression matrix; produce locally signed development build and demo documentation.

**Expected output:** A polished locally runnable MVP with verified desktop chrome and known limitations documented.

**Dependencies:** Milestones 1–4.

## 11. Engineering task list

| # | Title | Description | Acceptance criteria | Complexity |
| ---: | --- | --- | --- | --- |
| 1 | Create macOS utility target | Initialize macOS 15 SwiftUI app and unit-test target; configure `LSUIElement`. | Build launches without Dock icon and exposes a menu-bar item. | Small |
| 2 | Add MenuBarExtra window routing | Add menu actions and standard task/habit/settings windows with focus-existing-window behavior. | All menu routes work and do not duplicate windows. | Medium |
| 3 | Create placeholder pet asset contract | Add state-named red-panda placeholder assets and document replacement dimensions. | Still image renders at 2×/3× without code changes. | Small |
| 4 | Build the transparent overlay panel | Host SwiftUI pet content in a transparent, non-activating `NSPanel`. | Overlay stays above normal windows without stealing focus. | Large |
| 5 | Implement drag and monitor clamping | Move the panel from a custom gesture; clamp the pet's rect inside the panel against visible screen frames. | At least 48 points of pet, not panel margin, stay on a connected monitor. | Medium |
| 6 | Persist overlay state directly | Read/write pet visibility, display ID, and geometry with `UserDefaults`. | Relaunch restores a valid state without an interim abstraction. | Small |
| 7 | Define SwiftData models and test configuration | Create TaskItem/Habit/HabitLog models and app/in-memory container configuration. | Persistent and in-memory containers open successfully. | Medium |
| 8 | Build TaskList and TaskEditor | Use `@Query` for task lists and implement editor validation/UI. | Valid tasks appear reactively; blank titles are blocked. | Medium |
| 9 | Implement TaskManager commands | Create/complete/delete through `ModelContext`, including save-failure handling. | Completion timestamp/status and deletion behavior are unit-tested. | Medium |
| 10 | Implement simple pet reaction engine | Add observable mood/bubble/current priority and cancellable reset task. | Higher priority interrupts lower; no reaction queue exists. | Medium |
| 11 | Connect task events to reactions | Trigger visual feedback only after successful task mutations. | Add/complete reactions fire once after save. | Small |
| 12 | Add reminder fields and validation | Add optional task reminder controls and reject past times. | Future reminder persists; past time cannot save. | Small |
| 13 | Implement notification authorization/actions | Request permission in context; register Open Task and Mark Complete. | Allowed/denied/action routes behave correctly. | Medium |
| 14 | Build deterministic reminder scheduler | Add/replace/remove requests and re-add future incomplete reminders on launch. | Stable identifiers prevent duplicate pending requests. | Medium |
| 15 | Handle foreground reminder feedback | Route delivered foreground notification(s) to one reminder reaction. | Reminder state/bubble appears while app is running. | Small |
| 16 | Build daily habit model and UI | Implement daily habit creation, Today list, and inactive management. | Active daily habits persist and appear in Today. | Medium |
| 17 | Implement unique habit completion/undo | Add compound uniqueness, completion result, Today query, and undo. | One log exists per habit/day; duplicate completion does not celebrate. | Medium |
| 18 | Build task-only Quick Capture | Add focused capture panel, placement, task submission, and keyboard controls. | Save creates task; Escape causes no data change. | Medium |
| 19 | Register fixed global Quick Capture hotkey | Register Command-Option-P and present fallback status on conflict. | Registered hotkey opens focused capture; menus remain fallback. | Medium |
| 20 | Implement launch-at-login setting | Wire toggle to `SMAppService.mainApp` status/register/unregister. | State reflects service status and failures are visible. | Medium |
| 21 | Add accessibility and motion/sound support | Add VoiceOver labels and honor Reduce Motion/sound preferences. | Animation stops under Reduce Motion; controls are labeled. | Medium |
| 22 | Execute manual regression and package locally | Run defined manual scenarios; archive locally signed development build; document limits. | Regression log and runnable development build are available. | Medium |

## 12. Edge cases

| Situation | Required behavior |
| --- | --- |
| App restart | Restore persisted tasks/habits/settings, validate screen geometry, re-add future incomplete reminder requests, start pet idle. |
| Notification permission denied | Keep `reminderAt`, clearly show unavailable alert status, and link to notification settings when supported. |
| Reminder in the past | Reject with inline validation; do not schedule it. |
| Pet dragged outside visible screen | Clamp during drag end and launch; fall back to primary screen when saved display is absent. |
| Multiple reminders at once | Retain individual system requests, but show one count-based pet bubble. |
| Duplicate habit completion | Compound uniqueness and manager result leave one log and one celebration. |
| User quits | Persist regular data/settings; let macOS retain scheduled local notifications. |
| Full-screen apps | Hide pet by default; respect explicit Settings opt-in. |
| Multiple monitors | Store display ID/position; resolve disconnect/reconnect; show capture on pet/pointer screen. |
| macOS notifications | Document Focus, sleep, alert settings, and local-development signing as delivery limitations. |
| DST/time-zone changes | Derive Today from current local day key; regenerate future reminders on app launch. |
| Hotkey conflict | Report inability to register; leave pet/menu capture entry points usable. |
| Store failure | Preserve database, report recovery information, and do not send success feedback. |

## 13. Testing plan

### Automated unit tests

- SwiftData in-memory tests for TaskItem/Habit/HabitLog creation, task status/timestamps, `#Unique` habit safety, and persistence errors.
- Task validation, ordering, completion/deletion behavior, and reminder request identifiers.
- Reminder scheduling/replacement/cancellation and launch re-add behavior using a small fake notification client.
- Local day-key generation around DST, local midnight, and time-zone changes.
- Overlay frame clamping for primary/secondary/disconnected/resized displays.
- Reaction state mapping, priority interruption, click throttle, and reset-state decisions.

### Manual desktop-chrome matrix

| Area | Scenarios |
| --- | --- |
| Agent/menu app | No Dock icon; menu item stays available; normal windows activate/focus correctly. |
| Overlay | Drag across monitors; disconnect saved display; resize display; hide/show; verify ordinary app focus remains intact. |
| Notifications | Not determined, allowed, denied, Focus enabled, foreground/background, actions, and concurrent reminders. |
| Persistence | Normal quit, force quit after save, relaunch hidden pet, restored tasks/habits/position, future reminder re-add. |
| Habits | Repeated completion, undo, inactive habits, midnight and time-zone/DST behavior. |
| Capture | Pet/menu/hotkey entry points, capture screen placement, Escape/Return behavior, hotkey conflict fallback. |
| Accessibility | VoiceOver navigation, keyboard capture flow, increased contrast, Reduce Motion, and sound disabled. |
| Full screen | Safari/Xcode full-screen default hiding and opt-in behavior. |

### Release criteria

- Unit tests pass on the macOS 15 development machine.
- The manual matrix is completed, including at least one multi-monitor check when hardware is available.
- Normal restart loses no task, habit, position, or preference data.
- Permission and storage failures remain recoverable and honest.
- The README identifies the development-Mac/local-signing notification limitation.

## 14. Future roadmap

### V2 — deepen the companion

- Selectable otter, cat, dog, and red panda assets using the existing asset naming convention.
- Pet bond/XP, accessories, skins, custom names, and optional streak celebrations.
- A real readable Notes feature before introducing note capture again.
- Calendar integration, file/link capture, light search/tags, signed/notarized distribution, and optional cloud sync.

### V3 — intelligent personal workspace

- AI task breakdown with explicit user confirmation.
- RAG over user-selected notes, private local-LLM mode, and knowledge graph/second-brain views.
- Mobile companion, cross-device sync, and collaboration after the single-user local product is mature.

No roadmap item creates speculative MVP UI, network clients, model fields, protocols, or placeholders.

## 15. Final output

### Concise MVP summary

Build a native macOS 15+ agent utility with one draggable red panda, local task tracking, task reminders, daily habits, task-only Quick Capture, simple reactive animation, and durable local storage. The MVP succeeds when it makes progress feel lightly rewarding while staying small, dependable, and quiet.

### Recommended first technical milestone

Start with the Dock-less menu-bar shell and the `NSPanel` pet overlay. Activation, panel focus, dragging, Displays/Spaces, and monitor clamping are the highest-risk differentiators; prove them before making task-data architecture more elaborate.

### Suggested folder structure

```text
PetCompanion/
├── App/
│   ├── PetCompanionApp.swift
│   ├── MenuBarController.swift
│   └── AppSettings.swift
├── Models/
│   ├── TaskItem.swift
│   ├── Habit.swift
│   └── HabitLog.swift
├── Features/
│   ├── PetOverlay/
│   ├── Tasks/
│   ├── Habits/
│   ├── QuickCapture/
│   └── Settings/
├── Services/
│   ├── ReminderScheduler.swift
│   ├── NotificationManager.swift
│   ├── PetReactionEngine.swift
│   └── HotkeyManager.swift
├── Resources/
│   └── Assets.xcassets/
└── Tests/
    └── Unit/
```

### First 10 implementation tasks

1. Create the macOS 15 SwiftUI target and set `LSUIElement`.
2. Add the window-style `MenuBarExtra` and task/habit/settings window routes.
3. Define placeholder red-panda asset names and add the first idle still/frame.
4. Create the transparent non-activating `NSPanel` bridge.
5. Implement pet dragging and visible-screen clamping.
6. Persist pet visibility/display/position in `UserDefaults`.
7. Define SwiftData TaskItem/Habit/HabitLog models and in-memory tests.
8. Build Task List/Task Editor using `@Query` and the environment model context.
9. Implement task create/complete/delete commands in `TaskManager`.
10. Add the simple priority-based pet reaction engine and task-event integration.