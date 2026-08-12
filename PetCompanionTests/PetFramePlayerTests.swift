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

@MainActor
@Test func aStoppedPlayerResumesWhenTheSameReactionIsReapplied() {
    // Plan.md §3E: a hidden pet resumes when shown again. The manager
    // re-sends the unchanged mood and token, so that path must restart it.
    let subject = player(known: allIdleFrames)
    let token = UUID()
    subject.update(mood: .idle, token: token, reduceMotion: false)
    subject.stop()

    subject.update(mood: .idle, token: token, reduceMotion: false)
    subject.advance()

    #expect(subject.currentAssetName == "redpanda-idle-02")
}

@MainActor
@Test func enablingReduceMotionMidAnimationHoldsTheFirstFrame() {
    let subject = player(known: allIdleFrames)
    let token = UUID()
    subject.update(mood: .idle, token: token, reduceMotion: false)
    subject.advance()

    subject.update(mood: .idle, token: token, reduceMotion: true)
    subject.advance()

    #expect(subject.currentAssetName == "redpanda-idle-01")
}

@MainActor
@Test func disablingReduceMotionResumesTheSameAnimation() {
    let subject = player(known: allIdleFrames)
    let token = UUID()
    subject.update(mood: .idle, token: token, reduceMotion: true)

    subject.update(mood: .idle, token: token, reduceMotion: false)
    subject.advance()

    #expect(subject.currentAssetName == "redpanda-idle-02")
}

@MainActor
@Test func anUnchangedUpdateDoesNotRestartARunningAnimation() {
    let subject = player(known: allIdleFrames)
    let token = UUID()
    subject.update(mood: .idle, token: token, reduceMotion: false)
    subject.advance()

    subject.update(mood: .idle, token: token, reduceMotion: false)

    #expect(subject.currentAssetName == "redpanda-idle-02")
}

@MainActor
@Test func hidingTheOverlayStopsItsPlayer() {
    let subject = player(known: allIdleFrames)
    subject.update(mood: .idle, token: UUID(), reduceMotion: false)
    subject.advance()
    let suiteName = "PetOverlayManagerTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let manager = PetOverlayManager(defaults: defaults, player: subject)

    manager.toggleVisibility()
    subject.advance()

    #expect(subject.currentAssetName == "redpanda-idle-02")
}

@MainActor
@Test func reactionRaisedWhileHiddenIsDiscardedBeforeShowing() {
    let suiteName = "PetOverlayManagerTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let manager = PetOverlayManager(defaults: defaults, player: player(known: allIdleFrames))
    let engine = PetReactionEngine()
    manager.configure(reactionEngine: engine, petName: "Momo", showInFullScreen: false)

    manager.toggleVisibility()
    engine.show(event: .onTaskCompleted)
    manager.toggleVisibility()

    #expect(engine.mood == .idle)
    #expect(engine.bubble == nil)
}

@MainActor
@Test func reactionRaisedBeforeVisibleStartIsPreserved() {
    let suiteName = "PetOverlayManagerTests.\(UUID())"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let manager = PetOverlayManager(defaults: defaults, player: player(known: allIdleFrames))
    let engine = PetReactionEngine()
    manager.configure(reactionEngine: engine, petName: "Momo", showInFullScreen: false)
    engine.show(event: .onTaskCompleted)

    manager.start()

    #expect(engine.mood == .excited)
    #expect(engine.bubble == "You did it!")
}
