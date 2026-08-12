# Manual Regression Record

## Automated release checks — 2026-08-10

- [x] `xcodebuild test -scheme PetCompanion -destination 'platform=macOS,arch=arm64' -derivedDataPath /private/tmp/PetCompanionDerivedData22`
- [x] Development archive built at `/private/tmp/PetCompanion-development.xcarchive`.
- [x] Archive inspection confirms a universal arm64/x86_64 application with an ad-hoc signature.
- [x] README documents that notifications require a locally signed development bundle and that copying an unsigned build to another Mac is unsupported.

## Interactive desktop checks

These checks require a signed-in desktop session and, where noted, physical multi-monitor hardware. They must be marked after exercising the archived app; do not infer their outcome from unit tests.

| Area | Required checks | Status |
| --- | --- | --- |
| Agent/menu app | No Dock icon; menu item remains available; normal windows activate and focus. | Pending interactive check |
| Overlay | Drag across monitors; disconnect saved display; resize display; hide/show; ordinary app keeps focus. | Pending — multi-monitor hardware |
| Notifications | Permission states, Focus, foreground/background delivery, actions, concurrent reminders. | Pending interactive check |
| Persistence | Normal/force quit; relaunch restores tasks, habits, visibility, position, and reminders. | Pending interactive check |
| Habits | Repeated completion, undo, inactive habits, midnight and DST/time-zone behavior. | Pending interactive check |
| Capture | Pet/menu/hotkey entry points; placement; Escape/Return; hotkey conflict fallback. | Pending interactive check |
| Accessibility | VoiceOver navigation, keyboard capture, contrast, Reduce Motion, and sound disabled. | Pending interactive check |
| Full screen | Safari/Xcode full-screen default hiding and explicit opt-in. | Pending interactive check |

## Distribution note

This is a local development archive, not a notarized or redistributable build. Its ad-hoc signature is suitable for running on the development Mac only.
