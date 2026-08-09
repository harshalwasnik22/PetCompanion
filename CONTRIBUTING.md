# Contributing

Two people are working on this simultaneously. These rules exist to stop us from editing the same files at the same time, not to add ceremony.

## The loop

1. **Claim before you code.** Assign the issue to yourself on GitHub. An unassigned issue is fair game; an assigned one is not. This is the only thing preventing duplicated work.
2. **Branch per issue:** `feat/12-reminder-fields`, `fix/9-completion-timestamp`. Always include the issue number.
3. **Small PRs.** One issue, one PR. Reference it in the body with `Closes #12` so it auto-closes.
4. **Rebase, don't merge, before opening the PR:** `git fetch origin && git rebase origin/main`. Keeps history linear and makes project-file conflicts obvious early.
5. **The other person reviews.** No self-merges to `main`.

## Avoiding Xcode project-file conflicts

`project.pbxproj` is the one file that reliably breaks when two people work in parallel — every added file rewrites it, and Git cannot merge it sensibly.

**Use Xcode 16 buildable folders (synchronized folder references).** Each top-level folder from `Plan.md` §15 is added to the project *once* as a buildable folder. After that, creating a file inside it adds it to the build for everyone with **no `project.pbxproj` change at all**. This is the single most important convention here — it turns the usual constant conflict into a rare one.

Practical rules:

- Put new source files in an existing buildable folder. Do not drag files into the project navigator in a way that creates individual file references.
- Adding a *new top-level folder*, a target, a build setting, or a capability does touch `project.pbxproj`. Say so in the issue or in chat before you do it, so the other person can rebase rather than collide.
- **Never commit `xcuserdata/`.** It is gitignored; if it shows up in `git status`, something added it deliberately — don't.
- Schemes must be **shared** (Xcode → Manage Schemes → Shared) so they live in `xcshareddata` and both of us get them.

If you do hit a `project.pbxproj` conflict: do not hand-merge the XML. Take one side whole (`git checkout --theirs PetCompanion.xcodeproj/project.pbxproj`), reopen Xcode, and re-apply your project-level change through the UI. It is faster and far less likely to produce a subtly corrupt project.

## Two tracks that don't collide

The issue list is ordered, but it is not sequential. After **#1 (create the Xcode target)** is merged, two people can work continuously without touching each other's files:

| | Track A — desktop chrome (AppKit) | Track B — data and logic (SwiftData) |
| --- | --- | --- |
| First | #3 placeholder assets, #4 overlay panel | #7 SwiftData models, #8 task list/editor |
| Then | #5 drag and clamping, #6 persist overlay state | #9 TaskManager commands, #10 reaction engine |
| Then | #2 MenuBarExtra routing | #11 connect task events to reactions |

Track A lives in `Features/PetOverlay/` and `App/`. Track B lives in `Models/`, `Features/Tasks/`, and `Services/`. The one shared seam is #10/#11 — the reaction engine — which Track A consumes and Track B produces, so agree on `PetReactionEngine`'s public surface (§8 of `Plan.md`) before either of you starts.

After Milestone 2 lands, **Milestone 3 (reminders, #12–#15)** and **Milestone 4 (habits, #16–#17)** are fully independent — take one each.

## Code conventions

- Swift 6, strict concurrency. UI and panel controllers are `@MainActor`.
- No repository layer, no protocol-per-class, no dependency-injection framework. Concrete types, injected as `@Observable` objects. `Plan.md` §2 guardrail 3 is binding — if you find yourself writing a protocol with one conformer, don't.
- Views read data with `@Query` and call a manager for mutations.
- The model is `TaskItem`. Never name a type `Task`.
- Managers save before they report success or trigger a pet reaction.

## Tests

Unit tests only — no XCUITest. Run them before opening a PR.

Test the things that can actually be wrong: day-key generation across DST and time-zone changes, frame clamping against multi-screen fixtures, reaction priority and throttling, task validation and ordering, and reminder request identifiers. Use `ModelConfiguration(isStoredInMemoryOnly: true)` against the real models.

Desktop behavior — focus, dragging, monitors, notification delivery — is verified by hand against the matrix in `Plan.md` §13. Note in the PR which rows you ran.

## Commits

Present tense, one line, reference the issue when it isn't obvious:

```
Add TaskItem model and in-memory container config (#7)
Clamp pet rect, not panel frame, on drag end (#5)
```
