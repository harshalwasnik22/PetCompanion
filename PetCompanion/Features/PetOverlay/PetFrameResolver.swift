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
