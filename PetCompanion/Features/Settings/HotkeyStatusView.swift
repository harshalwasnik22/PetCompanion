import SwiftUI

@MainActor
struct HotkeyStatusView: View {
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        Form {
            Section("Quick Capture") {
                LabeledContent("Shortcut", value: "⌘⌥P")
                Text(hotkeyManager.status.message)
                    .foregroundStyle(hotkeyManager.status == .registered ? Color.secondary : Color.orange)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 320)
        .navigationTitle("Settings")
    }
}
