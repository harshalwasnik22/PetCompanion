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

@MainActor
struct StatusMenuView: View {
    @Environment(\.openWindow) private var openWindow

    @ObservedObject var overlayManager: PetOverlayManager
    private let controller = MenuBarController()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pet Companion")
                .font(.headline)

            Button("Add Task") {
                controller.open(.tasks, using: openWindow)
            }

            Button("Quick Capture") {
                controller.open(.quickCapture, using: openWindow)
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
