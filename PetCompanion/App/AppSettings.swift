import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginStatus: SMAppService.Status = .notRegistered
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var soundEnabled: Bool
    @Published private(set) var showPetInFullScreen: Bool
    @Published private(set) var petName: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.soundEnabled = defaults.object(forKey: PreferenceKey.soundEnabled) as? Bool ?? true
        self.showPetInFullScreen = defaults.bool(forKey: PreferenceKey.showPetInFullScreen)
        self.petName = defaults.string(forKey: PreferenceKey.petName) ?? "Momo"
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

    func setSoundEnabled(_ enabled: Bool) {
        soundEnabled = enabled
        defaults.set(enabled, forKey: PreferenceKey.soundEnabled)
    }

    func setShowPetInFullScreen(_ enabled: Bool) {
        showPetInFullScreen = enabled
        defaults.set(enabled, forKey: PreferenceKey.showPetInFullScreen)
    }

    func setPetName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        petName = trimmed.isEmpty ? "Momo" : trimmed
        defaults.set(petName, forKey: PreferenceKey.petName)
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

private enum PreferenceKey {
    static let soundEnabled = "appSettings.soundEnabled"
    static let showPetInFullScreen = "appSettings.showPetInFullScreen"
    static let petName = "appSettings.petName"
}
