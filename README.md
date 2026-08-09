# Pet Companion

A native macOS menu-bar utility with a draggable red panda that lives on your desktop, reacts when you finish work, and keeps local tasks, reminders, and daily habits. Local-first: no account, no network, no cloud.

**Status:** early implementation. The app shell builds and runs as a menu-bar agent; features are tracked in the issue list. [`Plan.md`](Plan.md) is the spec.

## Requirements

- macOS 15 or later
- Xcode 16 or later (needed for buildable folders and Swift 6)

## Getting started

```bash
git clone https://github.com/harshalwasnik22/PetCompanion.git
cd PetCompanion
open PetCompanion.xcodeproj
```

Or from the command line:

```bash
xcodebuild build -scheme PetCompanion -destination 'platform=macOS'
xcodebuild test  -scheme PetCompanion -destination 'platform=macOS'
```

Read `Plan.md` before your first issue — it defines every model, manager, and acceptance criterion, and the issue list maps 1:1 to §11.

## What it does

- **Pet overlay** — a transparent, always-on-top `NSPanel` you can drag anywhere; remembers its position and display across restarts.
- **Tasks** — create, complete, and delete with optional notes, due date, and one reminder. SwiftData-backed.
- **Reminders** — local `UNUserNotificationCenter` notifications with Open Task and Mark Complete actions.
- **Habits** — daily habits with a Today view, one completion per habit per local day.
- **Quick Capture** — a focused sticky card from the pet, the menu bar, or ⌘⌥P.
- **Reactions** — the panda changes pose and shows a short speech bubble when you make progress.

## Architecture in one paragraph

SwiftUI owns the normal windows and reads SwiftData through `@Query`. AppKit supplies the one thing SwiftUI cannot model: the transparent non-activating overlay panel. Concrete `@Observable` managers (`TaskManager`, `HabitManager`, `PetReactionEngine`) hold the logic and talk to `ModelContext` directly — there is no repository layer and no dependency protocols, by deliberate design. See §5 of `Plan.md`.

The task model is named `TaskItem`, not `Task`, so it does not shadow Swift's concurrency `Task`.

## Known limitations

- **Notifications need a signed bundle.** The project currently builds ad-hoc signed with no team, which is fine for everything up to Milestone 3. Before starting the reminder work (#13), set `DEVELOPMENT_TEAM` to your personal Apple ID team, or `UNUserNotificationCenter` registration will not behave. Copying an unsigned build to another Mac is not a supported path for reminders either way.
- **Built against the macOS 26.5 SDK with a 15.0 deployment target.** The compiler enforces API availability against 15.0, but nothing is runtime-tested on macOS 15 itself.
- No sandbox, no notarization, no auto-update. This is a local/portfolio build.
- Pet art starts as state-named placeholders (`redpanda-idle`, `redpanda-happy`, …); final art drops in without code changes.

## Contributing

Two people work on this at once — read [`CONTRIBUTING.md`](CONTRIBUTING.md) before your first branch. It covers the branch/issue workflow and how to avoid Xcode project-file conflicts.
