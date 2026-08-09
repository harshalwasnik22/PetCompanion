import AppKit
import SwiftUI

@main
@MainActor
struct PetCompanionApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Pet Companion", systemImage: "pawprint.fill") {
            StatusMenuView(overlayManager: appDelegate.overlayManager)
        }
        .menuBarExtraStyle(.window)

        Window("Tasks", id: AppWindow.tasks.id) {
            PlaceholderDestinationView(
                title: "Tasks",
                message: "Task management will appear here in the next milestone."
            )
        }
        .defaultSize(width: 480, height: 360)

        Window("Habits", id: AppWindow.habits.id) {
            PlaceholderDestinationView(
                title: "Habits",
                message: "Daily habits will appear here in the next milestone."
            )
        }
        .defaultSize(width: 480, height: 360)

        Window("Settings", id: AppWindow.settings.id) {
            PlaceholderDestinationView(
                title: "Settings",
                message: "Pet and notification preferences will appear here in a later milestone."
            )
        }
        .defaultSize(width: 480, height: 360)

        Window("Quick Capture", id: AppWindow.quickCapture.id) {
            PlaceholderDestinationView(
                title: "Quick Capture",
                message: "Focused task capture will appear here in a later milestone."
            )
        }
        .defaultSize(width: 320, height: 220)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let overlayManager = PetOverlayManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayManager.start()
    }
}
