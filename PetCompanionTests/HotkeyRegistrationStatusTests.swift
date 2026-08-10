import Carbon.HIToolbox
import Testing
@testable import PetCompanion

@Test func registeredStatusDescribesTheFixedShortcut() {
    #expect(HotkeyRegistrationStatus.registered.message == "Quick Capture shortcut: ⌘⌥P")
}

@Test func unavailableStatusKeepsAlternativeEntryPointsClear() {
    let status = HotkeyRegistrationStatus.unavailable(OSStatus(eventHotKeyExistsErr))

    #expect(status.message.contains("pet or menu bar"))
}
