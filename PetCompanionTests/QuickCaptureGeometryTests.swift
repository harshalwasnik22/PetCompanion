import CoreGraphics
import Testing
@testable import PetCompanion

@Test func captureFrameClampsToTheVisibleScreen() {
    let result = QuickCaptureGeometry.clampedFrame(
        CGRect(x: 900, y: -20, width: 332, height: 290),
        to: CGRect(x: 0, y: 0, width: 1_000, height: 800)
    )

    #expect(result.origin == CGPoint(x: 668, y: 0))
    #expect(result.maxX == 1_000)
}

@Test func captureFramePreservesAnAlreadyVisiblePlacement() {
    let frame = CGRect(x: 120, y: 180, width: 332, height: 290)

    #expect(QuickCaptureGeometry.clampedFrame(frame, to: CGRect(x: 0, y: 0, width: 1_000, height: 800)) == frame)
}
