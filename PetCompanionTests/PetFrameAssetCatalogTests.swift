import AppKit
import Testing
@testable import PetCompanion

@MainActor
@Test func generatedFramesResolveWithoutTheIdleFallback() {
    let resolver = PetFrameResolver(exists: { NSImage(named: $0) != nil })

    for mood in [PetMood.idle, .happy, .excited, .sleepy, .reminding] {
        for frame in 0..<PetAnimation.forMood(mood).frameCount {
            #expect(resolver.assetName(mood: mood, frame: frame) != "redpanda-idle")
        }
    }
}

@MainActor
@Test func draggedDeliberatelyUsesTheIdleFallback() {
    let resolver = PetFrameResolver(exists: { NSImage(named: $0) != nil })

    #expect(PetAnimation.forMood(.dragged).frameCount == 1)
    #expect(resolver.assetName(mood: .dragged, frame: 0) == "redpanda-idle")
}

@MainActor
@Test func generatedIdleFrameIsInTheAssetCatalog() {
    #expect(NSImage(named: "redpanda-idle-02") != nil)
}
