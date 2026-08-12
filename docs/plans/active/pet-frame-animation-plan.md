# Pet Frame Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the pet's on-screen appearance reflect its mood with frame-based animation, so real art can replace placeholders without a code change.

**Architecture:** Three new pure-ish units — an animation table, an asset-name resolver with a sequence/still/idle fallback chain, and an observable frame player with injectable timing — consumed by the existing `PetOverlayView`. The reaction engine is not modified; it already publishes `mood` and `reactionToken`.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing (`@Test` / `#expect`), Xcode synchronized folder groups, `sips` for placeholder art.

Spec: `docs/plans/active/pet-frame-animation.md`.

## Global Constraints

- Target destination is `platform=macOS`. There is no iOS simulator destination for this project.
- Full verification command: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS'`
- No new third-party dependencies. `sips` is the only external tool, and it ships with macOS.
- Swift 6 strict concurrency. UI and manager types are `@MainActor`, matching `PetReactionEngine` and `TaskManager`.
- The Xcode project uses `PBXFileSystemSynchronizedRootGroup`. New `.swift` files inside `PetCompanion/` and `PetCompanionTests/` join the target automatically — never hand-edit `project.pbxproj`.
- Do not modify `PetReactionEngine.swift`. The six moods and their priorities are fixed.
- Do not restyle Tasks, Habits, Settings, the menu bar, or Quick Capture. This work is the pet overlay only.
- Tests are top-level `@Test` functions, not methods in a struct, matching `NotificationManagerTests.swift`.
- Asset slugs are lowercase and hyphen-free: `idle`, `happy`, `excited`, `sleepy`, `dragged`, `reminding`.

## File Structure

| File | Responsibility |
| --- | --- |
| `PetCompanion/Features/PetOverlay/PetAnimation.swift` (new) | Frame count, per-frame duration, loop rule per mood; the `PetMood.assetSlug` mapping |
| `PetCompanion/Features/PetOverlay/PetFrameResolver.swift` (new) | Turn (species, mood, frame index) into an asset name, with fallback |
| `PetCompanion/Features/PetOverlay/PetFramePlayer.swift` (new) | Hold the current frame, advance it on a schedule, stop on demand |
| `PetCompanion/Features/PetOverlay/PetOverlayManager.swift` (modify) | Render `player.currentAssetName` instead of a literal |
| `scripts/generate-pet-frames.sh` (new) | Produce placeholder frame imagesets from the existing art |
| `PetCompanionTests/PetAnimationTests.swift` (new) | Table coverage |
| `PetCompanionTests/PetFrameResolverTests.swift` (new) | All three fallback branches |
| `PetCompanionTests/PetFramePlayerTests.swift` (new) | Frame advance, restart, Reduce Motion, stop |

Task 1 and Task 2 together are T1 in the spec; Task 4 is the spec's T2; Task 3 is T3; Task 5 is T4. They are split here so a reviewer can reject the resolver's fallback logic without rejecting the timing table.

---

### Task 1: Animation table

**Files:**
- Create: `PetCompanion/Features/PetOverlay/PetAnimation.swift`
- Test: `PetCompanionTests/PetAnimationTests.swift`

**Interfaces:**
- Consumes: `PetMood` from `PetCompanion/Services/PetReactionEngine.swift`
- Produces:
  - `struct PetAnimation: Equatable` with `let frameCount: Int`, `let frameDuration: Duration`, `let loops: Bool`
  - `static func PetAnimation.forMood(_ mood: PetMood) -> PetAnimation`
  - `var PetMood.assetSlug: String`

- [ ] **Step 1: Write the failing test**

Create `PetCompanionTests/PetAnimationTests.swift`:

```swift
import Foundation
import Testing
@testable import PetCompanion

@Test func everyMoodHasAFrameCountOfAtLeastOne() {
    let moods: [PetMood] = [.idle, .happy, .excited, .sleepy, .dragged, .reminding]

    for mood in moods {
        #expect(PetAnimation.forMood(mood).frameCount >= 1)
    }
}

@Test func idleIsTheLowCadenceLoopingAnimation() {
    // Plan.md §9 asks for a low-cadence idle. A fast idle reads as agitation,
    // not calm, so the slow frame duration is the requirement, not a detail.
    let idle = PetAnimation.forMood(.idle)

    #expect(idle.frameCount == 4)
    #expect(idle.frameDuration == .milliseconds(600))
    #expect(idle.loops)
}

@Test func draggedIsASingleHeldFrame() {
    let dragged = PetAnimation.forMood(.dragged)

    #expect(dragged.frameCount == 1)
    #expect(!dragged.loops)
}

@Test func happyPlaysOnceRatherThanLooping() {
    #expect(!PetAnimation.forMood(.happy).loops)
}

@Test func assetSlugsAreStableAndDistinctFromAccessibilityWording() {
    // The accessibility label says "being moved"; the asset is "dragged".
    // These must not be derived from each other.
    #expect(PetMood.dragged.assetSlug == "dragged")
    #expect(PetMood.idle.assetSlug == "idle")
    #expect(PetMood.reminding.assetSlug == "reminding")
}
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run|TEST"`

Expected: build FAILS with "cannot find 'PetAnimation' in scope".

- [ ] **Step 3: Write the implementation**

Create `PetCompanion/Features/PetOverlay/PetAnimation.swift`:

```swift
import Foundation

/// One mood's frame timing. Durations are deliberately slow for idle: Plan.md §9
/// asks for a low-cadence idle animation, and a fast loop reads as agitation.
struct PetAnimation: Equatable {
    let frameCount: Int
    let frameDuration: Duration
    let loops: Bool

    static func forMood(_ mood: PetMood) -> PetAnimation {
        switch mood {
        case .idle: PetAnimation(frameCount: 4, frameDuration: .milliseconds(600), loops: true)
        case .happy: PetAnimation(frameCount: 3, frameDuration: .milliseconds(120), loops: false)
        case .excited: PetAnimation(frameCount: 4, frameDuration: .milliseconds(100), loops: true)
        case .sleepy: PetAnimation(frameCount: 2, frameDuration: .milliseconds(900), loops: true)
        case .dragged: PetAnimation(frameCount: 1, frameDuration: .milliseconds(600), loops: false)
        case .reminding: PetAnimation(frameCount: 3, frameDuration: .milliseconds(140), loops: true)
        }
    }
}

extension PetMood {
    /// Asset filename component. Deliberately separate from the accessibility
    /// wording, which says "being moved" where the asset says "dragged".
    var assetSlug: String {
        switch self {
        case .idle: "idle"
        case .happy: "happy"
        case .excited: "excited"
        case .sleepy: "sleepy"
        case .dragged: "dragged"
        case .reminding: "reminding"
        }
    }
}
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "^✘|Test run|TEST"`

Expected: `** TEST SUCCEEDED **`, test count increased by 5.

- [ ] **Step 5: Commit**

```bash
git add PetCompanion/Features/PetOverlay/PetAnimation.swift PetCompanionTests/PetAnimationTests.swift
git commit -m "Add pet animation frame table"
```

---

### Task 2: Asset name resolver

**Files:**
- Create: `PetCompanion/Features/PetOverlay/PetFrameResolver.swift`
- Test: `PetCompanionTests/PetFrameResolverTests.swift`

**Interfaces:**
- Consumes: `PetMood.assetSlug` from Task 1
- Produces:
  - `struct PetFrameResolver` with `init(species: String = "redpanda", exists: @escaping (String) -> Bool)`
  - `func assetName(mood: PetMood, frame: Int) -> String`

- [ ] **Step 1: Write the failing test**

Create `PetCompanionTests/PetFrameResolverTests.swift`:

```swift
import Foundation
import Testing
@testable import PetCompanion

private func resolver(known: Set<String>, species: String = "redpanda") -> PetFrameResolver {
    PetFrameResolver(species: species, exists: { known.contains($0) })
}

@Test func aPresentFrameSequenceIsUsed() {
    let subject = resolver(known: ["redpanda-happy-01", "redpanda-happy-02"])

    #expect(subject.assetName(mood: .happy, frame: 0) == "redpanda-happy-01")
    #expect(subject.assetName(mood: .happy, frame: 1) == "redpanda-happy-02")
}

@Test func aMissingSequenceFallsBackToTheMoodStill() {
    let subject = resolver(known: ["redpanda-happy"])

    #expect(subject.assetName(mood: .happy, frame: 0) == "redpanda-happy")
}

@Test func aMissingMoodStillFallsBackToSpeciesIdle() {
    // Partial art is expected: shipping three moods must not render nothing
    // for the other three.
    let subject = resolver(known: ["redpanda-idle"])

    #expect(subject.assetName(mood: .reminding, frame: 0) == "redpanda-idle")
}

@Test func resolutionIsSpeciesScoped() {
    let subject = resolver(known: ["otter-happy-01", "redpanda-happy-01"], species: "otter")

    #expect(subject.assetName(mood: .happy, frame: 0) == "otter-happy-01")
}

@Test func frameNumbersArePaddedToTwoDigits() {
    let subject = resolver(known: ["redpanda-idle-10"])

    #expect(subject.assetName(mood: .idle, frame: 9) == "redpanda-idle-10")
}
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run|TEST"`

Expected: build FAILS with "cannot find 'PetFrameResolver' in scope".

- [ ] **Step 3: Write the implementation**

Create `PetCompanion/Features/PetOverlay/PetFrameResolver.swift`:

```swift
import Foundation

/// Turns a mood and frame index into an asset name, degrading rather than
/// failing when art is missing. This chain is what lets real art replace
/// placeholders with no code change, and what makes partial art safe.
struct PetFrameResolver {
    let species: String
    private let exists: (String) -> Bool

    init(species: String = "redpanda", exists: @escaping (String) -> Bool) {
        self.species = species
        self.exists = exists
    }

    func assetName(mood: PetMood, frame: Int) -> String {
        let sequence = "\(species)-\(mood.assetSlug)-\(String(format: "%02d", frame + 1))"
        if exists(sequence) { return sequence }

        let still = "\(species)-\(mood.assetSlug)"
        if exists(still) { return still }

        return "\(species)-idle"
    }
}
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "^✘|Test run|TEST"`

Expected: `** TEST SUCCEEDED **`, test count increased by 5.

- [ ] **Step 5: Commit**

```bash
git add PetCompanion/Features/PetOverlay/PetFrameResolver.swift PetCompanionTests/PetFrameResolverTests.swift
git commit -m "Add pet frame asset resolver with fallback chain"
```

---

### Task 3: Frame player

**Files:**
- Create: `PetCompanion/Features/PetOverlay/PetFramePlayer.swift`
- Test: `PetCompanionTests/PetFramePlayerTests.swift`

**Interfaces:**
- Consumes: `PetAnimation.forMood(_:)` (Task 1), `PetFrameResolver.assetName(mood:frame:)` (Task 2)
- Produces:
  - `@MainActor @Observable final class PetFramePlayer`
  - `init(resolver: PetFrameResolver)`
  - `private(set) var currentAssetName: String`
  - `func update(mood: PetMood, token: UUID, reduceMotion: Bool)`
  - `func advance()`
  - `func stop()`

`advance()` carries no access modifier, so it is internal and reachable from tests
via the existing `@testable import PetCompanion`. It is deliberately not private:
tests step frames deterministically instead of waiting on a clock, and the timing
task calls the same method. Do not widen it to `public`.

- [ ] **Step 1: Write the failing test**

Create `PetCompanionTests/PetFramePlayerTests.swift`:

```swift
import Foundation
import Testing
@testable import PetCompanion

@MainActor
private func player(known: Set<String>) -> PetFramePlayer {
    PetFramePlayer(resolver: PetFrameResolver(species: "redpanda", exists: { known.contains($0) }))
}

private let allIdleFrames: Set<String> = [
    "redpanda-idle-01", "redpanda-idle-02", "redpanda-idle-03", "redpanda-idle-04"
]
private let allHappyFrames: Set<String> = [
    "redpanda-happy-01", "redpanda-happy-02", "redpanda-happy-03"
]

@MainActor
@Test func advancingWalksThroughTheSequence() {
    let subject = player(known: allIdleFrames)
    subject.update(mood: .idle, token: UUID(), reduceMotion: false)

    #expect(subject.currentAssetName == "redpanda-idle-01")
    subject.advance()
    #expect(subject.currentAssetName == "redpanda-idle-02")
}

@MainActor
@Test func aLoopingAnimationWrapsToItsFirstFrame() {
    let subject = player(known: allIdleFrames)
    subject.update(mood: .idle, token: UUID(), reduceMotion: false)

    for _ in 0..<4 { subject.advance() }

    #expect(subject.currentAssetName == "redpanda-idle-01")
}

@MainActor
@Test func aNonLoopingAnimationHoldsItsLastFrame() {
    // happy's sequence is shorter than the engine's 2.5s reaction, so the last
    // frame has to hold rather than restart, or the pet stutters.
    let subject = player(known: allHappyFrames)
    subject.update(mood: .happy, token: UUID(), reduceMotion: false)

    for _ in 0..<10 { subject.advance() }

    #expect(subject.currentAssetName == "redpanda-happy-03")
}

@MainActor
@Test func aMoodChangeRestartsAtTheFirstFrame() {
    let subject = player(known: allIdleFrames.union(allHappyFrames))
    subject.update(mood: .idle, token: UUID(), reduceMotion: false)
    subject.advance()

    subject.update(mood: .happy, token: UUID(), reduceMotion: false)

    #expect(subject.currentAssetName == "redpanda-happy-01")
}

@MainActor
@Test func anEqualPriorityRefreshReplaysTheSequence() {
    // Two consecutive task-added reactions produce the same mood with a new
    // token. The second must replay the hop, not continue mid-sequence.
    let subject = player(known: allHappyFrames)
    subject.update(mood: .happy, token: UUID(), reduceMotion: false)
    subject.advance()
    #expect(subject.currentAssetName == "redpanda-happy-02")

    subject.update(mood: .happy, token: UUID(), reduceMotion: false)

    #expect(subject.currentAssetName == "redpanda-happy-01")
}

@MainActor
@Test func reduceMotionHoldsTheFirstFrameButStillSwapsTheMood() {
    // Issue #21: Reduce Motion stops frame animation but preserves state changes.
    let subject = player(known: allIdleFrames.union(allHappyFrames))
    subject.update(mood: .idle, token: UUID(), reduceMotion: true)
    subject.advance()

    #expect(subject.currentAssetName == "redpanda-idle-01")

    subject.update(mood: .happy, token: UUID(), reduceMotion: true)

    #expect(subject.currentAssetName == "redpanda-happy-01")
}

@MainActor
@Test func stoppingFreezesTheCurrentFrame() {
    let subject = player(known: allIdleFrames)
    subject.update(mood: .idle, token: UUID(), reduceMotion: false)

    subject.stop()
    subject.advance()

    #expect(subject.currentAssetName == "redpanda-idle-01")
}
```

- [ ] **Step 2: Run the suite to verify it fails**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run|TEST"`

Expected: build FAILS with "cannot find 'PetFramePlayer' in scope".

- [ ] **Step 3: Write the implementation**

Create `PetCompanion/Features/PetOverlay/PetFramePlayer.swift`:

```swift
import Foundation
import Observation

/// Holds the pet's current frame and advances it on the mood's cadence.
///
/// Timing lives in a cancellable `Task` rather than a `Timer`, matching
/// `PetReactionEngine.expiryTask`. `advance()` is separated from that task so
/// tests can step frames without waiting on a real clock.
@MainActor
@Observable
final class PetFramePlayer {
    private(set) var currentAssetName: String

    private let resolver: PetFrameResolver
    private var mood: PetMood = .idle
    private var animation: PetAnimation = .forMood(.idle)
    private var frame = 0
    private var token: UUID?
    private var isAnimating = false
    private var tickTask: Task<Void, Never>?

    init(resolver: PetFrameResolver) {
        self.resolver = resolver
        self.currentAssetName = resolver.assetName(mood: .idle, frame: 0)
    }

    /// Restarts on a new token as well as a new mood: an equal-priority reaction
    /// refreshes the same mood, and that must replay rather than continue.
    func update(mood: PetMood, token: UUID, reduceMotion: Bool) {
        guard mood != self.mood || token != self.token else { return }

        self.mood = mood
        self.token = token
        animation = .forMood(mood)
        frame = 0
        refreshAssetName()

        tickTask?.cancel()
        tickTask = nil
        isAnimating = !reduceMotion && animation.frameCount > 1
        guard isAnimating else { return }

        let duration = animation.frameDuration
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                do {
                    try await Task.sleep(for: duration)
                } catch {
                    return
                }
                guard let self, !Task.isCancelled else { return }
                advance()
            }
        }
    }

    func advance() {
        guard isAnimating else { return }

        let next = frame + 1
        if next < animation.frameCount {
            frame = next
        } else if animation.loops {
            frame = 0
        } else {
            // Hold the last frame and stop ticking; the engine ends the mood.
            stop()
            return
        }
        refreshAssetName()
    }

    func stop() {
        isAnimating = false
        tickTask?.cancel()
        tickTask = nil
    }

    private func refreshAssetName() {
        currentAssetName = resolver.assetName(mood: mood, frame: frame)
    }
}
```

- [ ] **Step 4: Run the suite to verify it passes**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "^✘|Test run|TEST"`

Expected: `** TEST SUCCEEDED **`, test count increased by 7.

- [ ] **Step 5: Commit**

```bash
git add PetCompanion/Features/PetOverlay/PetFramePlayer.swift PetCompanionTests/PetFramePlayerTests.swift
git commit -m "Add pet frame player with injectable frame stepping"
```

---

### Task 4: Placeholder frames

**Files:**
- Create: `scripts/generate-pet-frames.sh`
- Create: `PetCompanion/Resources/Assets.xcassets/redpanda-<mood>-<NN>.imageset/` for each generated frame

**Interfaces:**
- Consumes: nothing in Swift
- Produces: imagesets named exactly as `PetFrameResolver` expects — `redpanda-idle-01` … `redpanda-idle-04`, `redpanda-happy-01` … `-03`, `redpanda-excited-01` … `-04`, `redpanda-sleepy-01` … `-02`, `redpanda-reminding-01` … `-03`. `dragged` has one frame and resolves to the existing `redpanda-idle`, so it needs no imageset.

- [ ] **Step 1: Verify sips preserves alpha before generating anything**

This gate decides whether the task proceeds. Run:

```bash
cd /tmp && rm -rf alphacheck && mkdir alphacheck && cd alphacheck
SRC="$OLDPWD/PetCompanion/Resources/Assets.xcassets/redpanda-idle.imageset/redpanda-idle@3x.png"
sips -s format png --resampleHeightWidth 400 400 "$SRC" --out probe.png >/dev/null
sips -g hasAlpha probe.png
```

Expected: `hasAlpha: yes`.

If it reports `no`, STOP. Do not generate frames. Skip to Step 6 and record the
outcome — every mood then resolves through the fallback chain to
`redpanda-idle`, the engine still ships fully tested, and real art activates it
later. Do not generate opaque frames; a white box around the pet is worse than
no animation.

- [ ] **Step 2: Write the generation script**

Create `scripts/generate-pet-frames.sh`:

```bash
#!/bin/bash
# Generates placeholder pet frame imagesets from the single existing idle art.
#
# These are NOT final animation. PetOverlayView renders with .scaledToFit()
# inside a fixed frame, so a slightly smaller PNG reads as gentle breathing.
# That proves the frame pipeline; real art replaces these imagesets by name
# with no code change.
#
# sips cannot pad transparently (--padColor is RGB with no alpha), so scale is
# the only transform available that keeps the pet's transparent background.
set -euo pipefail

ASSETS="$(dirname "$0")/../PetCompanion/Resources/Assets.xcassets"
SOURCE="$ASSETS/redpanda-idle.imageset"

# mood:scale ramp, as percentages of the source size
FRAMES="idle:100,98,96,98 happy:100,108,104 excited:100,110,100,110 sleepy:100,97 reminding:100,104,96"

for entry in $FRAMES; do
  mood="${entry%%:*}"
  scales="${entry#*:}"
  index=1
  IFS=',' read -ra ramp <<< "$scales"
  for pct in "${ramp[@]}"; do
    name=$(printf "redpanda-%s-%02d" "$mood" "$index")
    dir="$ASSETS/$name.imageset"
    mkdir -p "$dir"
    for scale in 1 2 3; do
      case $scale in
        1) suffix=""; base=144 ;;
        2) suffix="@2x"; base=288 ;;
        3) suffix="@3x"; base=432 ;;
      esac
      px=$(( base * pct / 100 ))
      sips -s format png --resampleHeightWidth "$px" "$px" \
        "$SOURCE/redpanda-idle${suffix}.png" \
        --out "$dir/${name}${suffix}.png" >/dev/null
    done
    cat > "$dir/Contents.json" <<JSON
{
  "images" : [
    { "filename" : "${name}.png", "idiom" : "universal", "scale" : "1x" },
    { "filename" : "${name}@2x.png", "idiom" : "universal", "scale" : "2x" },
    { "filename" : "${name}@3x.png", "idiom" : "universal", "scale" : "3x" }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
    index=$(( index + 1 ))
  done
done

echo "Generated placeholder frames."
```

- [ ] **Step 3: Run the script**

```bash
chmod +x scripts/generate-pet-frames.sh
./scripts/generate-pet-frames.sh
ls PetCompanion/Resources/Assets.xcassets | grep redpanda
```

Expected: 16 new imageset directories plus the original `redpanda-idle.imageset`.

- [ ] **Step 4: Verify the generated frames kept their transparency**

```bash
sips -g hasAlpha PetCompanion/Resources/Assets.xcassets/redpanda-idle-02.imageset/redpanda-idle-02@3x.png
```

Expected: `hasAlpha: yes`. If `no`, delete every generated imageset
(`git clean -fd PetCompanion/Resources/Assets.xcassets`) and record the fallback
outcome in Step 6.

- [ ] **Step 5: Build to confirm the asset catalog still compiles**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "error:|Test run|TEST"`

Expected: `** TEST SUCCEEDED **`, same test count as after Task 3.

- [ ] **Step 6: Commit**

```bash
git add scripts/generate-pet-frames.sh PetCompanion/Resources/Assets.xcassets
git commit -m "Generate placeholder pet frame imagesets"
```

If Step 1 or Step 4 failed, commit only the script with a message recording that
`sips` could not preserve alpha and that all moods fall back to `redpanda-idle`
until real art arrives.

---

### Task 5: Render the current frame

**Files:**
- Modify: `PetCompanion/Features/PetOverlay/PetOverlayManager.swift` — the `PetOverlayView` struct, currently lines 236–301
- Test: none new; covered by Tasks 1–3 plus a manual check

**Interfaces:**
- Consumes: `PetFramePlayer` (Task 3), `PetFrameResolver` (Task 2)
- Produces: no new public API

- [ ] **Step 1: Add the player to the view**

In `PetOverlayView`, immediately after the existing
`@State private var lastTranslation: CGSize = .zero`, add:

```swift
    /// Production resolution asks the asset catalog directly. Tests never reach
    /// this closure; they inject a known name set instead.
    @State private var player = PetFramePlayer(
        resolver: PetFrameResolver(exists: { NSImage(named: $0) != nil })
    )
```

`NSImage` needs AppKit. `PetOverlayManager.swift` already has `import AppKit` on
line 1 (verified), so no import change is needed.

- [ ] **Step 2: Replace the hardcoded image**

Change the literal at what is currently line 261:

```swift
            Image("redpanda-idle")
```

to:

```swift
            Image(player.currentAssetName)
```

Change nothing else in that chain — `.resizable()`, `.scaledToFit()`, the
`.frame(...)`, the accessibility modifiers, the gesture, and the tap handler all
stay exactly as they are.

- [ ] **Step 3: Drive the player from the engine**

Add these modifiers to the `ZStack`, directly above the existing
`.animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: reactionEngine.reactionToken)`
line:

```swift
        .onAppear {
            player.update(
                mood: reactionEngine.mood,
                token: reactionEngine.reactionToken,
                reduceMotion: reduceMotion
            )
        }
        .onChange(of: reactionEngine.reactionToken) {
            player.update(
                mood: reactionEngine.mood,
                token: reactionEngine.reactionToken,
                reduceMotion: reduceMotion
            )
        }
        .onDisappear {
            // A hidden pet must not keep a timing task alive. Plan.md §3E:
            // discard transient reactions while hidden, resume idle when shown.
            player.stop()
        }
```

`reactionToken` changes on every accepted reaction including an equal-priority
refresh of the same mood, so observing it alone is sufficient — a separate
`onChange(of: reactionEngine.mood)` would be redundant.

- [ ] **Step 4: Run the suite**

Run: `xcodebuild test -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' 2>&1 | grep -E "^✘|error:|Test run|TEST"`

Expected: `** TEST SUCCEEDED **`, same test count as after Task 4.

- [ ] **Step 5: Manual check**

```bash
xcodebuild -project PetCompanion.xcodeproj -scheme PetCompanion -destination 'platform=macOS' -derivedDataPath /tmp/dd-petanim build
open /tmp/dd-petanim/Build/Products/Debug/PetCompanion.app
```

Confirm, in order:
1. The pet breathes gently at rest rather than sitting perfectly still.
2. Adding a task changes its appearance for the reaction, then returns to idle.
3. Dragging holds a single pose and does not animate.
4. Enabling System Settings → Accessibility → Display → Reduce Motion stops the
   frame animation while mood changes still swap the image.

Quit the app when done.

- [ ] **Step 6: Record the manual scenario**

Append to `docs/ManualRegression.md`, matching the surrounding format:

```markdown
## Pet frame animation

1. At rest, the pet plays its idle animation.
2. Completing a task plays the reaction animation, then returns to idle.
3. Dragging holds a single pose.
4. With Reduce Motion enabled, frames stop but mood still changes the image.
```

- [ ] **Step 7: Commit**

```bash
git add PetCompanion/Features/PetOverlay/PetOverlayManager.swift docs/ManualRegression.md
git commit -m "Render the pet's current animation frame"
```

---

## Self-review

**Spec coverage.** Every spec section maps to a task: components table → Tasks 1–3
and 5; fallback chain → Task 2; species from day one → Task 2's `species`
parameter and its species-scoped test; data flow and token restart → Task 3's
`update(mood:token:reduceMotion:)` plus Task 5 Step 3; cadence → Task 1; Reduce
Motion → Task 3's test and Task 5 Step 3; hidden pet → Task 3's `stop()` and
Task 5's `onDisappear`; placeholder frames → Task 4; testing → Tasks 1–3;
manual evidence → Task 5 Steps 5–6.

**Type consistency.** `PetAnimation.forMood(_:)`, `PetMood.assetSlug`,
`PetFrameResolver.assetName(mood:frame:)`, and
`PetFramePlayer.update(mood:token:reduceMotion:)` / `advance()` / `stop()` /
`currentAssetName` are spelled identically everywhere they appear.

**Known gap, deliberate.** `dragged` has one frame and no generated imageset, so
it resolves to `redpanda-idle`. That is correct — a held pose needs no sequence —
but it means the drag pose is visually identical to idle until real art exists.
Task 5's manual check step 3 verifies the animation stops, not that the pose
differs.
