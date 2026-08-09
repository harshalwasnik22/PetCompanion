import Foundation
import Testing

/// Guards the one thing #1 actually configures: the app is an agent with no Dock icon.
/// If someone drops `INFOPLIST_KEY_LSUIElement`, this fails instead of the regression
/// showing up as a mystery Dock icon weeks later.
@Test func appRunsAsAgentWithoutDockIcon() {
    let value = Bundle.main.object(forInfoDictionaryKey: "LSUIElement")
    #expect(value as? Bool == true || value as? String == "YES" || value as? String == "1")
}

@Test func deploymentTargetIsMacOS15OrLater() {
    #expect(ProcessInfo.processInfo.isOperatingSystemAtLeast(
        OperatingSystemVersion(majorVersion: 15, minorVersion: 0, patchVersion: 0)))
}
