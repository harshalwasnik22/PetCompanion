import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var hotkeyManager: HotkeyManager
    @ObservedObject var appSettings: AppSettings
    @ObservedObject var overlayManager: PetOverlayManager
    let notificationManager: NotificationManager
    @State private var notificationStatus = "Checking notification permission…"

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

            Section("Pet") {
                TextField("Pet name", text: Binding(
                    get: { appSettings.petName },
                    set: { name in
                        appSettings.setPetName(name)
                        overlayManager.setPetName(appSettings.petName)
                    }
                ))
                Toggle("Show pet over full-screen apps", isOn: Binding(
                    get: { appSettings.showPetInFullScreen },
                    set: { enabled in
                        appSettings.setShowPetInFullScreen(enabled)
                        overlayManager.setShowInFullScreen(enabled)
                    }
                ))
            }

            Section("Notifications") {
                Toggle("Play reaction sounds", isOn: Binding(
                    get: { appSettings.soundEnabled },
                    set: { enabled in appSettings.setSoundEnabled(enabled) }
                ))
                Text(notificationStatus)
                    .foregroundStyle(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development")
                Text("Pet Companion stores your tasks locally on this Mac.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 320)
        .navigationTitle("Settings")
        .onAppear { appSettings.refreshLaunchAtLoginStatus() }
        .task { await refreshNotificationStatus() }
    }

    private func refreshNotificationStatus() async {
        switch await notificationManager.authorizationStatus() {
        case .authorized: notificationStatus = "Notifications are allowed."
        case .provisional: notificationStatus = "Notifications are delivered quietly."
        case .denied: notificationStatus = "Notifications are disabled in System Settings."
        case .notDetermined: notificationStatus = "Notifications are requested when you add a reminder."
        case .ephemeral: notificationStatus = "Notifications are temporarily available."
        @unknown default: notificationStatus = "Notification status is unavailable."
        }
    }
}
