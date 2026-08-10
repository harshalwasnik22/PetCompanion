import AppKit
import SwiftUI

enum AppWindow: String {
    case tasks
    case habits
    case settings
    case quickCapture

    var id: String { rawValue }
}

/// Routes menu-bar actions to singleton SwiftUI windows and explicitly activates
/// this agent app so a newly opened normal window receives keyboard input.
@MainActor
final class MenuBarController {
    func open(_ destination: AppWindow, using openWindow: OpenWindowAction) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: destination.id)

        DispatchQueue.main.async {
            if let window = NSApp.windows.first(where: { $0.identifier?.rawValue == destination.id }) {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }
}

/// The menu-bar item's label, which doubles as the place where the notification
/// manager gets its window-opening callback.
///
/// `openWindow` is only reachable from a `View`, and this label is the one view
/// that exists for the whole life of the app — the popover's contents only exist
/// while it is open, so wiring from there would leave "Open Task" dead until the
/// user happened to click the menu bar first.
///
/// `.labelStyle(.iconOnly)` keeps the status item to the paw glyph while leaving
/// the title for VoiceOver; without it the menu bar renders the text as well.
@MainActor
struct NotificationMenuBarLabel: View {
    @Environment(\.openWindow) private var openWindow
    let notificationManager: NotificationManager
    private let controller = MenuBarController()

    var body: some View {
        Label("Pet Companion", systemImage: "pawprint.fill")
            .labelStyle(.iconOnly)
            .onAppear {
                notificationManager.openTasks = {
                    controller.open(.tasks, using: openWindow)
                }
            }
    }
}

@MainActor
struct StatusMenuView: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var overlayManager: PetOverlayManager
    let quickCaptureController: QuickCaptureController
    private let controller = MenuBarController()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pet Companion")
                .font(.headline)

            Button("Add Task") {
                controller.open(.tasks, using: openWindow)
            }

            Button("Quick Capture") {
                quickCaptureController.show()
            }

            Button("Tasks") {
                controller.open(.tasks, using: openWindow)
            }

            Button("Habits") {
                controller.open(.habits, using: openWindow)
            }

            Button(overlayManager.isVisible ? "Hide Pet" : "Show Pet") {
                overlayManager.toggleVisibility()
            }

            Menu("Pets") {
                Toggle("Red Panda", isOn: .constant(true))
                    .disabled(true)
                Text("More pets later")
                    .disabled(true)
            }

            Divider()

            Button("Settings") {
                controller.open(.settings, using: openWindow)
            }

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 220)
    }
}

struct PlaceholderDestinationView: View {
    let title: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: "pawprint.fill", description: Text(message))
            .frame(minWidth: 480, minHeight: 320)
    }
}
