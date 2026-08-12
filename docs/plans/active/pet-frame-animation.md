# Pet frame animation

Design spec. Written 2026-08-12.

Spec location follows this repository's existing `docs/plans/active/` convention
rather than the brainstorming skill's default path, matching `habits.md`.

## Problem

`PetReactionEngine` tracks six moods — idle, happy, excited, sleepy, dragged,
reminding — and drives the speech bubble correctly. The renderer ignores all of
them: `PetOverlayManager.swift:261` is `Image("redpanda-idle")`, an unconditional
literal. Completing a task shows a bubble next to a pet whose appearance never
changes.

This is not new scope. `Plan.md` already specifies it:

- §3A: "It uses a quiet idle animation and clear visual states while reacting."
- §3A: placeholder "frames named by state, for example `redpanda-idle` and
  `redpanda-happy`; final art can replace them without code changes."
- §9: "Use low-cadence idle animation only when Reduce Motion is off."
- §3E: "If Reduce Motion is enabled, do not start frame animation — use the
  state's still image instead."

The asset contract from #3 was defined and never consumed.

## Goal

The pet's appearance reflects its mood, with frame-based animation, and real art
can replace the placeholders without a code change.

## Non-goals

- No design tokens, shared components, or restyling of any window. Tasks, Habits,
  Settings, the menu bar, and Quick Capture stay stock SwiftUI. Character lives
  in the pet.
- No speech bubble redesign. Its current styling stays.
- No new moods. The six in `PetMood` are the complete set.
- No sound. `soundEnabled` already exists and is out of scope here.
- No sprite atlas or texture packing. Individual imagesets, as #3 established.

## Assumptions

- Placeholder frames are acceptable in the repository as committed assets, so the
  app builds and runs standalone before real art exists.
- Final art will be supplied later as imagesets with the same names, per §3A.
- Partial art is expected and safe: shipping three moods of real art leaves the
  other three on their fallback rather than rendering nothing.

## Current behaviour and constraints

- `PetOverlayView` reads `@Environment(\.accessibilityReduceMotion)` at line 238
  and already gates its one existing animation, `.easeInOut(0.2)` keyed on
  `reactionEngine.reactionToken`, at line 288.
- The accessibility label at line 265 is
  `"\(petName) the red panda, \(moodName)"`. Issue #48 rewrites the species part;
  this work must not conflict with that.
- `PetOverlayManager.swift` is the largest file in the app at 301 lines. New code
  goes in new files.
- `reactionToken` changes on every accepted reaction, including an equal-priority
  refresh of the same mood.
- `dragged` is presented with `duration: nil`, so it persists until the drag ends.
- The reaction engine's `show(_:)` discards any presentation whose priority is
  lower than the current one, so drag pose protection is already enforced there.

## Design

### Components

| Unit | Responsibility | Depends on |
| --- | --- | --- |
| `PetAnimation` | Value type: frame count, per-frame duration, loop mode. Static table `PetMood -> PetAnimation` | nothing |
| `PetFrameResolver` | Asset name for (species, mood, frame), with the fallback chain | injected `exists:` closure |
| `PetFramePlayer` | `@MainActor @Observable`; advances the frame index over time | the two above |
| `PetOverlayView` | Renders `Image(player.currentAssetName)` | `PetFramePlayer` |

`PetAnimation` and `PetFrameResolver` are pure. `PetFramePlayer` owns the only
timing. The view owns no animation logic.

### Fallback chain

```
<species>-<mood>-01 … NN    frame sequence, when present
        ↓ absent
<species>-<mood>            single still
        ↓ absent
<species>-idle              always present
```

`PetFrameResolver` takes `exists: (String) -> Bool`, injected. Production passes
a closure backed by `NSImage(named:) != nil`; tests pass a set of known names, so
the fallback logic is testable without adding assets to the test bundle.

### Species from day one

`PetFrameResolver` takes a species parameter immediately, defaulting to red panda
until M6 lands. Issue #48 ("Route the selected species through the overlay
renderer") then becomes a one-line change passing the selected species, instead
of a rewrite of the same line this work changes. Without this, #48 and this work
both rewrite `PetOverlayManager.swift:261` and conflict.

### Data flow

```
PetReactionEngine.mood ─┐
                        ├→ PetFramePlayer → currentAssetName → PetOverlayView
PetReactionEngine.reactionToken ─┘
```

The player restarts its sequence on `reactionToken`, not only on `mood`. An
equal-priority reaction refreshes the same mood, so a second consecutive "task
added" must replay the hop from frame 0 rather than continue mid-sequence.

### Cadence

§9 calls for a low-cadence idle, so idle is deliberately slow and quiet.

| Mood | Frames | Per frame | Loop | Cycle |
| --- | ---: | ---: | --- | --- |
| idle | 4 | 600ms | loop | 2.4s |
| happy | 3 | 120ms | once, hold last | 0.36s |
| excited | 4 | 100ms | loop | 0.4s |
| sleepy | 2 | 900ms | loop | 1.8s |
| dragged | 1 | — | hold | — |
| reminding | 3 | 140ms | loop | 0.42s |

Looping moods loop for as long as the engine holds that mood; the engine's own
duration ends the reaction and returns to idle. `happy` plays once and holds its
last frame until the engine resets, so a short sequence does not stutter.

Timing uses a `Task` with `Task.sleep`, matching `PetReactionEngine.expiryTask`,
rather than a `Timer`. The player cancels the running task on every mood or token
change.

### Reduce Motion

Reduce Motion holds frame 0 and never advances it. Mood changes still swap the
still image — that is precisely what #21's "Reduce Motion stops frame animation
but preserves state changes and bubbles" requires. Suppressing the mood change
too would fail that criterion.

### Hidden pet

The player stops when the overlay is hidden and resumes at idle when shown, per
§3E: "If hidden, discard transient visual reactions and resume idle when shown."
An invisible pet must not keep a timing task alive.

## Placeholder frames

Verified tooling on this machine: `sips` is present; PIL and ImageMagick are not.

`sips` cannot pad transparently — its `--padColor` takes RGB with no alpha, so
padding to fake a vertical offset would produce opaque bars. It can resample,
which preserves PNG alpha.

Because `PetOverlayView` uses `.scaledToFit()` inside a fixed
`PetOverlayManager.petRect` frame, a slightly smaller PNG renders smaller inside
the same box. Placeholder frames are therefore the existing image resampled to a
small scale ramp — for idle, roughly 100%, 98%, 96%, 98% — which reads as gentle
breathing.

Source is 144×144 at 1x with @2x and @3x variants; every generated frame keeps
all three scales and its own `Contents.json`, matching the existing imageset.

Generation is a committed script under `scripts/`, not a build phase, so the
assets in the repository are plain checked-in PNGs that real art can overwrite.

## Tasks

**T1 — Animation table and resolver.** Owns `PetCompanion/Features/PetOverlay/PetAnimation.swift`
(new) and `PetCompanion/Features/PetOverlay/PetFrameResolver.swift` (new), plus
`PetCompanionTests/PetAnimationTests.swift` (new). Pure logic, no assets, no view
changes.

**T2 — Placeholder frame generation.** Owns `scripts/generate-pet-frames.sh` (new)
and the generated imagesets under `PetCompanion/Resources/Assets.xcassets/`.
Verify `sips` resampling preserves alpha before generating the full set. If it
does not, generate nothing: every mood then resolves through the chain to
`redpanda-idle`, the engine ships fully built and tested, and real art activates
it on arrival. Do not generate opaque frames — a white box around the pet is
worse than no animation. Resampling the same source into per-mood stills is not
an alternative either, since every mood would look identical.

**T3 — Frame player.** Owns `PetCompanion/Features/PetOverlay/PetFramePlayer.swift`
(new) and `PetCompanionTests/PetFramePlayerTests.swift` (new). Injectable clock
or sleep function so tests never wait on a real one, following the pattern used
for the reminder coalescing window in #15.

**T4 — Renderer wiring.** Owns the `Image` call and surrounding view code in
`PetCompanion/Features/PetOverlay/PetOverlayManager.swift`. The only task that
touches an existing file.

## Acceptance criteria and evidence

| Criterion | Evidence |
| --- | --- |
| Every `PetMood` has an animation entry | Exhaustive switch; compiler enforces, plus a table test |
| A frame sequence is used when present | Resolver test with a seeded `exists` set |
| A missing sequence falls back to the mood still | Resolver test |
| A missing mood still falls back to species idle | Resolver test |
| Mood change restarts at frame 0 | Player test |
| Equal-priority refresh restarts the sequence | Player test driven by `reactionToken` |
| Reduce Motion holds frame 0 but still swaps the still | Player test with the flag set |
| Hidden pet stops the player | Player test |
| Pet renders its mood on screen | Manual check; added to `docs/ManualRegression.md` |

## Risks

- `sips` alpha preservation on resample is unverified. T2 verifies it first and
  has a stated fallback.
- A scale-ramp placeholder is a weaker motion than real frame art. It proves the
  pipeline, not the final feel, and should not be mistaken for finished work.
- Landing this before #48 is preferable. If #48 lands first, T4 rebases onto the
  species-aware renderer rather than the literal.
- #22 is the manual regression gate. It should run after this, not before.

## Verification

`xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS'`

There is no iOS simulator destination for this project; macOS is the only one.
