import AppKit
import SwiftData
import SwiftUI

@main
@MainActor
struct PetCompanionApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    /// Opened once at launch. A failure is carried rather than thrown so the app
    /// can explain itself instead of crashing, and so nothing silently falls back
    /// to a throwaway in-memory store that would accept saves and lose them.
    private let store = Result { try AppModelContainer.make() }

    var body: some Scene {
        MenuBarExtra("Pet Companion", systemImage: "pawprint.fill") {
            backedByStore {
                StatusMenuView(overlayManager: appDelegate.overlayManager)
            }
        }
        .menuBarExtraStyle(.window)

        Window("Tasks", id: AppWindow.tasks.id) {
            backedByStore {
                TaskListView()
            }
        }
        .defaultSize(width: 480, height: 360)

        Window("Habits", id: AppWindow.habits.id) {
            backedByStore {
                PlaceholderDestinationView(
                    title: "Habits",
                    message: "Daily habits will appear here in the next milestone."
                )
            }
        }
        .defaultSize(width: 480, height: 360)

        Window("Settings", id: AppWindow.settings.id) {
            backedByStore {
                PlaceholderDestinationView(
                    title: "Settings",
                    message: "Pet and notification preferences will appear here in a later milestone."
                )
            }
        }
        .defaultSize(width: 480, height: 360)

        Window("Quick Capture", id: AppWindow.quickCapture.id) {
            backedByStore {
                PlaceholderDestinationView(
                    title: "Quick Capture",
                    message: "Focused task capture will appear here in a later milestone."
                )
            }
        }
        .defaultSize(width: 320, height: 220)
    }

    /// Puts the model container in the environment, or replaces the content with
    /// recovery information when the store could not be opened.
    @ViewBuilder
    private func backedByStore(@ViewBuilder _ content: () -> some View) -> some View {
        switch store {
        case .success(let container):
            content().modelContainer(container)
        case .failure(let error):
            StorageRecoveryView(error: error)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let overlayManager = PetOverlayManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayManager.start()
    }
}
