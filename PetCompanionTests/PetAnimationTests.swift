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
