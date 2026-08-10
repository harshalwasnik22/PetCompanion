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
            backedByStore { container in
                StatusMenuView(
                    overlayManager: appDelegate.overlayManager,
                    quickCaptureController: appDelegate.quickCaptureController(for: container)
                )
            }
        }
        .menuBarExtraStyle(.window)

        Window("Tasks", id: AppWindow.tasks.id) {
            backedByStore { _ in
                TaskListView()
            }
        }
        .defaultSize(width: 480, height: 360)

        Window("Habits", id: AppWindow.habits.id) {
            backedByStore { _ in
                PlaceholderDestinationView(
                    title: "Habits",
                    message: "Daily habits will appear here in the next milestone."
                )
            }
        }
        .defaultSize(width: 480, height: 360)

        Window("Settings", id: AppWindow.settings.id) {
            backedByStore { _ in
                PlaceholderDestinationView(
                    title: "Settings",
                    message: "Pet and notification preferences will appear here in a later milestone."
                )
            }
        }
        .defaultSize(width: 480, height: 360)

        Window("Quick Capture", id: AppWindow.quickCapture.id) {
            backedByStore { container in
                QuickCaptureWindowFallback(
                    quickCaptureController: appDelegate.quickCaptureController(for: container)
                )
            }
        }
        .defaultSize(width: 320, height: 220)
    }

    /// Puts the model container and the reaction engine in the environment, or
    /// replaces the content with recovery information when the store could not
    /// be opened.
    ///
    /// The engine goes in here rather than on individual scenes because
    /// `@Environment(PetReactionEngine.self)` traps at runtime when the value is
    /// missing. Every scene already routes through this helper, so any future
    /// window that builds a `TaskManager` — Quick Capture in #18 — gets the
    /// engine without anyone having to remember.
    @ViewBuilder
    private func backedByStore<Content: View>(
        @ViewBuilder _ content: (ModelContainer) -> Content
    ) -> some View {
        switch store {
        case .success(let container):
            content(container)
                .modelContainer(container)
                .environment(appDelegate.reactionEngine)
        case .failure(let error):
            StorageRecoveryView(error: error)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let overlayManager = PetOverlayManager()
    private var captureController: QuickCaptureController?
    let reactionEngine = PetReactionEngine()

    func applicationDidFinishLaunching(_ notification: Notification) {
        overlayManager.start()
    }

    func quickCaptureController(for modelContainer: ModelContainer) -> QuickCaptureController {
        if let captureController { return captureController }

        let controller = QuickCaptureController(
            modelContainer: modelContainer,
            overlayManager: overlayManager,
            reactionEngine: reactionEngine
        )
        overlayManager.onPetClicked = { [weak controller] in
            controller?.show()
        }
        captureController = controller
        return controller
    }
}
