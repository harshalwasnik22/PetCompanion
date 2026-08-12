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
