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
