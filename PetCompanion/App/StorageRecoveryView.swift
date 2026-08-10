import AppKit
import SwiftUI

/// Shown in place of normal content when the store cannot be opened.
///
/// It deliberately offers no "reset" or "start fresh" button: the database is
/// intact and a one-click wipe is exactly how people lose data during a
/// transient failure like a full disk or a permissions problem.
struct StorageRecoveryView: View {
    let error: any Error

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Storage unavailable", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            Text("Pet Companion could not open its database, so tasks and habits cannot be saved right now. Your existing data has not been changed or deleted.")
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            Text(AppModelContainer.storeURL.path(percentEncoded: false))
                .font(.caption.monospaced())
                .textSelection(.enabled)
                .foregroundStyle(.secondary)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Quit") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
        .padding(12)
        .frame(width: 320)
    }
}
