import Foundation
import Observation

enum PetMood: Equatable {
    case idle
    case happy
    case excited
    case sleepy
    case dragged
    case reminding
}

enum PetEvent: Equatable {
    case onPetClicked
    case onPetDragged(isDragging: Bool)
    case onTaskAdded
    case onTaskCompleted
    case onReminderDue(count: Int)
    case onHabitCompleted
}

/// Owns the one visible pet reaction. Events are deliberately not queued: a
/// higher priority interrupts, an equal priority refreshes, and a lower one is
/// discarded while the current reaction is visible.
@MainActor
@Observable
final class PetReactionEngine {
    private(set) var mood: PetMood = .idle
    private(set) var bubble: String?
    private(set) var priority = 0

    /// Changes whenever a visible reaction is replaced. It gives renderers a
    /// stable way to restart an animation without retaining an event queue.
    private(set) var reactionToken = UUID()

    private var expiryTask: Task<Void, Never>?
    private var lastActivity = Date()
    private var lastGreeting: Date?

    private static let clickThrottle: TimeInterval = 2
    private static let sleepyDelay: TimeInterval = 10 * 60

    init() {
        scheduleSleep()
    }

    func show(event: PetEvent) {
        let now = Date()

        if event == .onPetClicked,
           let lastGreeting,
           now.timeIntervalSince(lastGreeting) < Self.clickThrottle {
            lastActivity = now
            return
        }

        lastActivity = now

        switch event {
        case .onPetClicked:
            lastGreeting = now
            show(.init(mood: .happy, bubble: "Hi!", duration: 2, priority: 40))

        case .onPetDragged(let isDragging):
            if isDragging {
                show(.init(mood: .dragged, bubble: nil, duration: nil, priority: 50))
            } else if mood == .dragged {
                resetToIdle()
            }

        case .onTaskAdded:
            show(.init(mood: .happy, bubble: "I’ll remember that!", duration: 2.5, priority: 60))

        case .onTaskCompleted:
            show(.init(mood: .excited, bubble: "You did it!", duration: 3, priority: 80))

        case .onReminderDue(let count):
            let bubble = count == 1 ? "Psst—time for your task!" : "You have \(count) reminders."
            show(.init(mood: .reminding, bubble: bubble, duration: 6, priority: 100))

        case .onHabitCompleted:
            show(.init(mood: .happy, bubble: "Streak secured!", duration: 3, priority: 75))
        }
    }

    func discardTransientReaction() {
        guard mood != .idle, mood != .dragged else { return }
        resetToIdle()
    }

    private func show(_ presentation: Presentation) {
        guard presentation.priority >= priority else {
            return
        }

        expiryTask?.cancel()
        mood = presentation.mood
        bubble = presentation.bubble
        priority = presentation.priority
        reactionToken = UUID()

        guard let duration = presentation.duration else { return }
        expiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.resetToIdle()
        }
    }

    private func resetToIdle() {
        expiryTask?.cancel()
        expiryTask = nil
        mood = .idle
        bubble = nil
        priority = 0
        reactionToken = UUID()
        scheduleSleep()
    }

    private func scheduleSleep() {
        expiryTask?.cancel()
        let delay = max(0, Self.sleepyDelay - Date().timeIntervalSince(lastActivity))
        expiryTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard !Task.isCancelled, self?.priority == 0 else { return }
            self?.mood = .sleepy
        }
    }
}

private struct Presentation {
    let mood: PetMood
    let bubble: String?
    let duration: TimeInterval?
    let priority: Int
}
