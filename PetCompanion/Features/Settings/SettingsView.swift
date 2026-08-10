import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var appSettings: AppSettings

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: Binding(
                    get: { appSettings.launchAtLoginEnabled },
                    set: { enabled in appSettings.setLaunchAtLogin(enabled) }
                ))
                Text(appSettings.launchAtLoginStatusMessage)
                    .foregroundStyle(.secondary)
                if let error = appSettings.launchAtLoginError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section("Quick Capture") {
                LabeledContent("Shortcut", value: "⌘⌥P")
                Text(hotkeyManager.status.message)
                    .foregroundStyle(hotkeyManager.status == .registered ? Color.secondary : Color.orange)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 320)
        .navigationTitle("Settings")
        .onAppear { appSettings.refreshLaunchAtLoginStatus() }
    }
}
