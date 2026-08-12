import Carbon.HIToolbox
import Combine
import Foundation

enum HotkeyRegistrationStatus: Equatable {
    case registered
    case unavailable(OSStatus)

    var message: String {
        switch self {
        case .registered:
            "Quick Capture shortcut: ⌘⌥P"
        case .unavailable:
            "Quick Capture shortcut is unavailable. Use the pet or menu bar instead."
        }
    }
}

/// Registers the MVP's one fixed global shortcut. Events come from Carbon, so
/// the callback returns to the main actor before showing the SwiftUI capture UI.
@MainActor
final class HotkeyManager: ObservableObject {
    @Published private(set) var status: HotkeyRegistrationStatus = .unavailable(noErr)

    private var hotKey: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var onTriggered: (() -> Void)?

    nonisolated(unsafe) private static weak var activeManager: HotkeyManager?

    func register(onTriggered: @escaping () -> Void) {
        self.onTriggered = onTriggered
        guard hotKey == nil else { return }

        Self.activeManager = self
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.eventHandlerCallback,
            1,
            &eventType,
            nil,
            &eventHandler
        )
        guard installStatus == noErr else {
            status = .unavailable(installStatus)
            return
        }

        let id = EventHotKeyID(signature: OSType(0x5043_4D50), id: 1) // "PCMP"
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_P),
            UInt32(cmdKey | optionKey),
            id,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        if registerStatus == noErr {
            status = .registered
        } else {
            status = .unavailable(registerStatus)
            if let eventHandler { RemoveEventHandler(eventHandler) }
            eventHandler = nil
        }
    }

    private func trigger() {
        onTriggered?()
    }

    private static let eventHandlerCallback: EventHandlerUPP = { _, _, _ in
        DispatchQueue.main.async {
            HotkeyManager.activeManager?.trigger()
        }
        return noErr
    }
}
