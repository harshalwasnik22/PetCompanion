import AppKit
import SwiftData
import SwiftUI

@MainActor
final class QuickCaptureController {
    static let panelSize = CGSize(width: 332, height: 290)

    private let modelContainer: ModelContainer
    private let overlayManager: PetOverlayManager
    private let reactionEngine: PetReactionEngine
    private var panel: NSPanel?

    init(
        modelContainer: ModelContainer,
        overlayManager: PetOverlayManager,
        reactionEngine: PetReactionEngine
    ) {
        self.modelContainer = modelContainer
        self.overlayManager = overlayManager
        self.reactionEngine = reactionEngine
    }

    func show() {
        let panel = makePanelIfNeeded()
        // The panel hosts SwiftUI outside the scene graph, so it gets no
        // environment from the app. Everything it needs is handed over here.
        panel.contentView = NSHostingView(
            rootView: QuickCaptureView(
                reactionEngine: reactionEngine,
                onCancel: { [weak self] in self?.dismiss() },
                onSaved: { [weak self] in self?.dismiss() }
            )
            .modelContainer(modelContainer)
        )
        panel.setFrame(overlayManager.quickCaptureFrame(for: panel.frame.size), display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }

        let panel = NSPanel(
            contentRect: CGRect(origin: .zero, size: Self.panelSize),
            styleMask: [.titled, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.transient, .ignoresCycle]
        self.panel = panel
        return panel
    }
}

enum QuickCaptureGeometry {
    static func clampedFrame(_ frame: CGRect, to visibleFrame: CGRect) -> CGRect {
        CGRect(
            x: min(max(frame.minX, visibleFrame.minX), visibleFrame.maxX - frame.width),
            y: min(max(frame.minY, visibleFrame.minY), visibleFrame.maxY - frame.height),
            width: frame.width,
            height: frame.height
        )
    }
}

@MainActor
private struct QuickCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    let reactionEngine: PetReactionEngine
    @FocusState private var titleIsFocused: Bool

    let onCancel: () -> Void
    let onSaved: () -> Void

    @State private var title = ""
    @State private var notes = ""
    @State private var showsDetails = false
    @State private var hasDueDate = false
    @State private var dueAt = Date.now
    @State private var hasReminder = false
    @State private var reminderAt = Date.now
    @State private var errorMessage: String?

    private var input: TaskEditorInput { TaskEditorInput(title: title, notes: notes) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Quick Capture", systemImage: "note.text")
                    .font(.headline)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(.plain)
            }

            TextField("What needs doing?", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleIsFocused)
                .onSubmit(save)

            DisclosureGroup("Add details", isExpanded: $showsDetails) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...5)
                        .onKeyPress { press in
                            guard press.key == .return,
                                  press.modifiers.contains(.command) else { return .ignored }
                            save()
                            return .handled
                        }
                    Toggle("Due date", isOn: $hasDueDate)
                    if hasDueDate { DatePicker("Due", selection: $dueAt) }
                    Toggle("Reminder", isOn: $hasReminder)
                    if hasReminder { DatePicker("Remind me", selection: $reminderAt) }
                }
                .padding(.top, 4)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel, action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(input.validatedTitle == nil)
            }
        }
        .padding(18)
        .frame(width: QuickCaptureController.panelSize.width)
        .onAppear { titleIsFocused = true }
        .onExitCommand(perform: onCancel)
    }

    private func save() {
        guard input.validatedTitle != nil else { return }
        do {
            try TaskManager(modelContext: modelContext, reactionEngine: reactionEngine).create(
                title: title,
                notes: notes,
                dueAt: hasDueDate ? dueAt : nil,
                reminderAt: hasReminder ? reminderAt : nil
            )
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

@MainActor
struct QuickCaptureWindowFallback: View {
    let quickCaptureController: QuickCaptureController

    var body: some View {
        ContentUnavailableView(
            "Quick Capture",
            systemImage: "note.text",
            description: Text("Use the menu-bar Quick Capture action to open the focused card.")
        )
        .frame(width: 320, height: 220)
        .onAppear { quickCaptureController.show() }
    }
}
