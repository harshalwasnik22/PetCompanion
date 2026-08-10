import Testing
@testable import PetCompanion

@MainActor
@Test func launchAtLoginStateReflectsTheServiceStatus() {
    let settings = AppSettings()

    #expect(settings.launchAtLoginEnabled == (settings.launchAtLoginStatus == .enabled))
}
