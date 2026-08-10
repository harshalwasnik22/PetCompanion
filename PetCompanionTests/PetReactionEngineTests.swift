import Testing
@testable import PetCompanion

@MainActor
struct PetReactionEngineTests {
    @Test func taskCompletionMapsToCelebration() {
        let engine = PetReactionEngine()

        engine.show(event: .onTaskCompleted)

        #expect(engine.mood == .excited)
        #expect(engine.bubble == "You did it!")
        #expect(engine.priority == 80)
    }

    @Test func higherPriorityReminderInterruptsCurrentReaction() {
        let engine = PetReactionEngine()
        engine.show(event: .onTaskAdded)

        engine.show(event: .onReminderDue(count: 3))

        #expect(engine.mood == .reminding)
        #expect(engine.bubble == "You have 3 reminders.")
        #expect(engine.priority == 100)
    }

    @Test func lowerPriorityEventDoesNotReplaceReminder() {
        let engine = PetReactionEngine()
        engine.show(event: .onReminderDue(count: 1))
        let reminderToken = engine.reactionToken

        engine.show(event: .onTaskAdded)

        #expect(engine.mood == .reminding)
        #expect(engine.reactionToken == reminderToken)
    }

    @Test func equalPriorityEventReplacesInsteadOfQueueing() {
        let engine = PetReactionEngine()
        engine.show(event: .onTaskCompleted)
        let firstToken = engine.reactionToken

        engine.show(event: .onTaskCompleted)

        #expect(engine.mood == .excited)
        #expect(engine.reactionToken != firstToken)
    }

    @Test func petGreetingsAreThrottledForTwoSeconds() {
        let engine = PetReactionEngine()
        engine.show(event: .onPetClicked)
        let greetingToken = engine.reactionToken

        engine.show(event: .onPetClicked)

        #expect(engine.mood == .happy)
        #expect(engine.reactionToken == greetingToken)
    }
}
