import AppKit
import SwiftUI

@MainActor
final class PetOverlayManager: NSObject, ObservableObject {
    static let panelSize = CGSize(width: 320, height: 260)
    static let petRect = CGRect(x: 88, y: 0, width: 144, height: 144)
    static let minimumVisiblePetLength: CGFloat = 48

    @Published private(set) var isVisible: Bool
    var onPetClicked: (() -> Void)?

    private let defaults: UserDefaults
    private let player: PetFramePlayer
    private var panel: NSPanel?
    private var reactionEngine: PetReactionEngine?
    private var petName = "Momo"
    private var showInFullScreen = false

    init(defaults: UserDefaults = .standard, player: PetFramePlayer? = nil) {
        self.defaults = defaults
        self.player = player ?? PetFramePlayer(
            resolver: PetFrameResolver(exists: { NSImage(named: $0) != nil })
        )
        self.isVisible = defaults.object(forKey: PetOverlayPreferences.isVisible) as? Bool ?? true
        super.init()
    }

    func start() {
        guard panel == nil else { return }

        let restoredFrame = restoredPanelFrame()
        let panel = NSPanel(
            contentRect: restoredFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        applyCollectionBehavior(to: panel)
        panel.contentView = overlayContentView()

        self.panel = panel
        applyVisibility()
    }

    func toggleVisibility() {
        isVisible.toggle()
        defaults.set(isVisible, forKey: PetOverlayPreferences.isVisible)
        applyVisibility()
    }

    func configure(reactionEngine: PetReactionEngine, petName: String, showInFullScreen: Bool) {
        self.reactionEngine = reactionEngine
        self.petName = petName
        self.showInFullScreen = showInFullScreen
        if let panel {
            applyCollectionBehavior(to: panel)
            panel.contentView = overlayContentView()
        }
    }

    func setPetName(_ name: String) {
        petName = name
        if let panel { panel.contentView = overlayContentView() }
    }

    func setShowInFullScreen(_ enabled: Bool) {
        showInFullScreen = enabled
        if let panel { applyCollectionBehavior(to: panel) }
    }

    private func applyVisibility() {
        if isVisible {
            if let reactionEngine {
                player.update(
                    mood: reactionEngine.mood,
                    token: reactionEngine.reactionToken,
                    reduceMotion: player.reduceMotion
                )
            }
            panel?.orderFrontRegardless()
        } else {
            player.stop()
            panel?.orderOut(nil)
        }
    }

    private func applyCollectionBehavior(to panel: NSPanel) {
        panel.collectionBehavior = showInFullScreen
            ? [.transient, .ignoresCycle, .canJoinAllSpaces, .fullScreenAuxiliary]
            : [.transient, .ignoresCycle]
    }

    private func overlayContentView() -> NSHostingView<some View> {
        let engine = reactionEngine ?? PetReactionEngine()
        return NSHostingView(
            rootView: PetOverlayView(
                player: player,
                petName: petName,
                onDragChanged: { [weak self] translation in self?.movePanel(by: translation) },
                onDragEnded: { [weak self] in self?.finishDrag() },
                onPetClicked: { [weak self] in self?.onPetClicked?() }
            )
            .environment(engine)
        )
    }

    private func movePanel(by translation: CGSize) {
        guard let panel else { return }
        panel.setFrameOrigin(CGPoint(
            x: panel.frame.origin.x + translation.width,
            y: panel.frame.origin.y - translation.height
        ))
    }

    private func finishDrag() {
        guard let panel else { return }
        let screen = screenContainingPet(in: panel.frame) ?? NSScreen.main
        guard let screen else { return }

        let clamped = PetOverlayGeometry.clampedPanelFrame(
            panel.frame,
            petRect: Self.petRect,
            to: screen.visibleFrame,
            minimumVisibleLength: Self.minimumVisiblePetLength
        )
        panel.setFrame(clamped, display: true)
        save(frame: clamped, on: screen)
    }

    private func restoredPanelFrame() -> CGRect {
        guard let screen = restoredScreen() ?? NSScreen.main else {
            return CGRect(origin: .zero, size: Self.panelSize)
        }

        let fallback = CGRect(
            x: screen.visibleFrame.maxX - Self.panelSize.width - 24,
            y: screen.visibleFrame.minY + 24,
            width: Self.panelSize.width,
            height: Self.panelSize.height
        )
        let savedOrigin: CGPoint
        if defaults.object(forKey: PetOverlayPreferences.positionX) != nil,
           defaults.object(forKey: PetOverlayPreferences.positionY) != nil {
            savedOrigin = CGPoint(
                x: defaults.double(forKey: PetOverlayPreferences.positionX),
                y: defaults.double(forKey: PetOverlayPreferences.positionY)
            )
        } else {
            savedOrigin = fallback.origin
        }

        return PetOverlayGeometry.clampedPanelFrame(
            CGRect(origin: savedOrigin, size: Self.panelSize),
            petRect: Self.petRect,
            to: screen.visibleFrame,
            minimumVisibleLength: Self.minimumVisiblePetLength
        )
    }

    private func restoredScreen() -> NSScreen? {
        let savedID = (defaults.object(forKey: PetOverlayPreferences.displayID) as? NSNumber)?.uint32Value
        return NSScreen.screens.first { screen in
            screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber == NSNumber(value: savedID ?? 0)
        }
    }

    private func screenContainingPet(in panelFrame: CGRect) -> NSScreen? {
        let petFrame = panelFrame.offsetBy(dx: Self.petRect.minX, dy: Self.petRect.minY)
        let petCenter = CGPoint(x: petFrame.midX, y: petFrame.midY)
        return NSScreen.screens.first { $0.frame.contains(petCenter) }
    }

    private func save(frame: CGRect, on screen: NSScreen) {
        defaults.set(frame.origin.x, forKey: PetOverlayPreferences.positionX)
        defaults.set(frame.origin.y, forKey: PetOverlayPreferences.positionY)
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber {
            defaults.set(number.uint32Value, forKey: PetOverlayPreferences.displayID)
        }
    }

    func quickCaptureFrame(for size: CGSize) -> CGRect {
        let screen: NSScreen
        let proposedOrigin: CGPoint

        if isVisible,
           let panel,
           let petScreen = screenContainingPet(in: panel.frame) {
            screen = petScreen
            proposedOrigin = CGPoint(
                x: panel.frame.maxX + 12,
                y: panel.frame.maxY - size.height
            )
        } else {
            screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main!
            proposedOrigin = CGPoint(
                x: NSEvent.mouseLocation.x + 16,
                y: NSEvent.mouseLocation.y - size.height - 16
            )
        }

        return QuickCaptureGeometry.clampedFrame(
            CGRect(origin: proposedOrigin, size: size),
            to: screen.visibleFrame
        )
    }
}

enum PetOverlayGeometry {
    static func clampedPanelFrame(
        _ panelFrame: CGRect,
        petRect: CGRect,
        to visibleFrame: CGRect,
        minimumVisibleLength: CGFloat
    ) -> CGRect {
        let minimumX = visibleFrame.minX - petRect.width + minimumVisibleLength
        let maximumX = visibleFrame.maxX - minimumVisibleLength
        let minimumY = visibleFrame.minY - petRect.height + minimumVisibleLength
        let maximumY = visibleFrame.maxY - minimumVisibleLength

        let petOrigin = CGPoint(
            x: min(max(panelFrame.minX + petRect.minX, minimumX), maximumX),
            y: min(max(panelFrame.minY + petRect.minY, minimumY), maximumY)
        )
        return CGRect(
            x: petOrigin.x - petRect.minX,
            y: petOrigin.y - petRect.minY,
            width: panelFrame.width,
            height: panelFrame.height
        )
    }
}

private enum PetOverlayPreferences {
    static let isVisible = "petOverlay.isVisible"
    static let positionX = "petOverlay.positionX"
    static let positionY = "petOverlay.positionY"
    static let displayID = "petOverlay.displayID"
}

@MainActor
private struct PetOverlayView: View {
    @Environment(PetReactionEngine.self) private var reactionEngine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let player: PetFramePlayer
    let petName: String
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    let onPetClicked: () -> Void

    @State private var lastTranslation: CGSize = .zero

    var body: some View {
        ZStack(alignment: .bottom) {
            if let bubble = reactionEngine.bubble {
                Text(bubble)
                    .font(.callout.weight(.medium))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .frame(maxWidth: 260)
                    .offset(y: -150)
                    .accessibilityHidden(true)
            }
            Image(player.currentAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: PetOverlayManager.petRect.width, height: PetOverlayManager.petRect.height)
                .accessibilityLabel("\(petName) the red panda, \(moodName)")
                .accessibilityHint("Double-click for Quick Capture.")
                .accessibilityAddTraits(.isButton)
                .padding(.bottom, 0)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            let delta = CGSize(
                                width: value.translation.width - lastTranslation.width,
                                height: value.translation.height - lastTranslation.height
                            )
                            lastTranslation = value.translation
                            onDragChanged(delta)
                        }
                        .onEnded { _ in
                            lastTranslation = .zero
                            onDragEnded()
                        }
                )
                .onTapGesture(perform: onPetClicked)
                .accessibilityAction(.default, onPetClicked)
        }
        .frame(width: PetOverlayManager.panelSize.width, height: PetOverlayManager.panelSize.height, alignment: .bottom)
        .onAppear {
            updatePlayer()
        }
        .onChange(of: reactionEngine.reactionToken) {
            updatePlayer()
        }
        .onChange(of: reduceMotion) {
            updatePlayer()
        }
        .onDisappear {
            // A hidden pet must not keep a timing task alive. Plan.md §3E:
            // discard transient reactions while hidden, resume idle when shown.
            player.stop()
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: reactionEngine.reactionToken)
    }

    private func updatePlayer() {
        player.update(
            mood: reactionEngine.mood,
            token: reactionEngine.reactionToken,
            reduceMotion: reduceMotion
        )
    }

    private var moodName: String {
        switch reactionEngine.mood {
        case .idle: "idle"
        case .happy: "happy"
        case .excited: "excited"
        case .sleepy: "sleepy"
        case .dragged: "being moved"
        case .reminding: "reminding you"
        }
    }
}
