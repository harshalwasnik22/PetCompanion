import AppKit
import SwiftUI

@main
struct PetCompanionApp: App {
    var body: some Scene {
        MenuBarExtra("Pet Companion", systemImage: "pawprint.fill") {
            // Placeholder shell. Real destinations and routing land in #2.
            Text("Pet Companion")
                .font(.headline)
                .padding(.bottom, 4)

            Divider()

            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.window)
    }
}
