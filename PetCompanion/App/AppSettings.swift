import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatus: SMAppService.Status = .notRegistered
    @Published private(set) var launchAtLoginError: String?

    init() {
        refreshLaunchAtLoginStatus()
    }

    func refreshLaunchAtLoginStatus() {
        let status = SMAppService.mainApp.status
        launchAtLoginStatus = status
        launchAtLoginEnabled = status == .enabled
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLoginError = error.localizedDescription
        }
        refreshLaunchAtLoginStatus()
    }

    var launchAtLoginStatusMessage: String {
        switch launchAtLoginStatus {
        case .enabled:
            "Pet Companion launches when you sign in."
        case .requiresApproval:
            "Approve Pet Companion in System Settings → General → Login Items."
        case .notRegistered:
            "Pet Companion does not launch at sign-in."
        case .notFound:
            "Launch at login is unavailable for this app installation."
        @unknown default:
            "Launch-at-login status is unavailable."
        }
    }
}
