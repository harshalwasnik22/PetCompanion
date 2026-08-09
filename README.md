# Pet Companion

A native macOS menu-bar utility with a draggable red panda that lives on your desktop, reacts when you finish work, and keeps local tasks, reminders, and daily habits. Local-first: no account, no network, no cloud.

**Status:** pre-implementation. [`Plan.md`](Plan.md) is the spec; the Xcode project does not exist yet (issue #1).

## Requirements

- macOS 15 or later
- Xcode 16 or later (needed for buildable folders and Swift 6)

## Getting started

```bash
git clone https://github.com/harshalwasnik22/PetCompanion.git
cd PetCompanion
open PetCompanion.xcodeproj   # once issue #1 lands
```

Until issue #1 is merged there is nothing to build. Read `Plan.md` first — it defines every model, manager, and acceptance criterion, and the issue list maps 1:1 to §11.

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

- **Notifications need a signed bundle.** They work on a development Mac through Xcode's local signing. Copying an unsigned build to another Mac is not a supported path for reminders.
- No sandbox, no notarization, no auto-update. This is a local/portfolio build.
- Pet art starts as state-named placeholders (`redpanda-idle`, `redpanda-happy`, …); final art drops in without code changes.

## Contributing

Two people work on this at once — read [`CONTRIBUTING.md`](CONTRIBUTING.md) before your first branch. It covers the branch/issue workflow and how to avoid Xcode project-file conflicts.
