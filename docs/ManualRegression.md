# Manual Regression Record

## Automated release checks — 2026-08-12

- [x] `xcodebuild test -scheme PetCompanion -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/PetCompanionDerivedData21`
- [x] Development archive built at `/private/tmp/PetCompanion-2026-08-12.xcarchive` and launched successfully.
- [x] Archive inspection confirms a universal arm64/x86_64 application with an ad-hoc signature.
- [x] README documents that notifications require a locally signed development bundle and that copying an unsigned build to another Mac is unsupported.

## Interactive desktop checks

These checks were run in a signed-in desktop session on a single 1470×956 display. The archived app was launched to confirm it is runnable; interactive behavior was exercised with the equivalent Debug build from the same revision. Rows that need unavailable hardware or a development signing identity remain explicitly limited rather than being inferred from unit tests.

| Area | Result | Evidence and limitations |
| --- | --- | --- |
| Agent/menu app | Pass | App runs as an accessory without a Dock icon; the paw menu remains available; Tasks, Quick Capture, and Settings open and accept focus. |
| Overlay | Pass on one display; multi-display limited | Drag, hide/show, ordinary-app focus, and exact position restoration passed. Cross-display dragging and display disconnect/resize were not run because only one physical display was available; geometry unit tests passed. |
| Notifications | Blocked for delivery/Focus; logic tests pass | The machine has no Apple Development signing identity, so permission states, Focus behavior, foreground/background delivery, and actions cannot be validated honestly. Scheduler, authorization, action, concurrent-reminder, and reconciliation tests passed with the notification client test double. |
| Persistence | Pass | Three existing tasks, the empty habit state, visibility, exact overlay position, sound/full-screen settings, and pet name survived normal relaunches. Tasks, habit count, overlay position, and settings also survived `SIGKILL` and relaunch. |
| Habits | Pass with simulated calendar boundaries | Add Habit and empty-state flows were inspected. Unit tests cover repeated completion, same-day undo, inactive history, local-midnight rollover, time-zone changes, and DST boundaries; the system clock was not changed during the desktop run. |
| Capture | Pass | Pet and paw-menu entry points, keyboard-only capture, Return submission, Escape dismissal, placement, and global-hotkey registration/fallback tests passed. |
| Accessibility | Pass | Accessibility hierarchy exposes labelled pet, menu controls, settings, tasks, and capture fields. Keyboard capture, Reduce Motion, sound-disabled visual feedback, and persisted accessibility settings passed. |
| Full screen | Pass | With the preference disabled, no PetCompanion window appeared in a genuine full-screen Code Space. Enabling the preference and relaunching produced one visible pet window in that Space. The original enabled preference was restored afterward. |

## Distribution note

This is a local development archive, not a notarized or redistributable build. Its ad-hoc signature verifies on disk and is suitable for running on the development Mac only. Completing the notification row requires signing into Xcode with an Apple ID, selecting the personal development team, rebuilding, and rerunning the notification matrix. Completing the multi-display overlay row requires a second physical display.

## Pet frame animation

1. At rest, the pet plays its idle animation.
2. Completing a task plays the reaction animation, then returns to idle.
3. Dragging holds a single pose.
4. With Reduce Motion enabled, frames stop but mood still changes the image.
