import CoreGraphics
import Testing
@testable import PetCompanion

@Test func clampKeepsAtLeastFortyEightPointsOfPetVisibleAtRightEdge() {
    let result = PetOverlayGeometry.clampedPanelFrame(
        CGRect(x: 980, y: 100, width: 320, height: 260),
        petRect: CGRect(x: 88, y: 0, width: 144, height: 144),
        to: CGRect(x: 0, y: 0, width: 1_000, height: 800),
        minimumVisibleLength: 48
    )

    #expect(result.minX == 864)
    #expect(result.minX + 88 + 48 == 1_000)
}

@Test func clampUsesPetRectRatherThanTransparentPanelMargin() {
    let result = PetOverlayGeometry.clampedPanelFrame(
        CGRect(x: -320, y: -260, width: 320, height: 260),
        petRect: CGRect(x: 88, y: 0, width: 144, height: 144),
        to: CGRect(x: 0, y: 0, width: 1_000, height: 800),
        minimumVisibleLength: 48
    )

    #expect(result.minX == -184)
    #expect(result.minY == -96)
}
