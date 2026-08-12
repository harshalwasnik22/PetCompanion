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
        guard mood != self.mood || token != self.token || !isAnimating else { return }

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
