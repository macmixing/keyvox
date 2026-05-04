import AppKit
import Combine
import CoreGraphics
import QuartzCore
import SwiftUI

class OverlayVisibilityManager: ObservableObject {
    @Published var isVisible: Bool = false
    @Published var shouldDismiss: Bool = false
    @Published var isHandsFreeLocked: Bool = false
    @Published var isHandsFreeModifierPreviewActive: Bool = false
}

class OverlayManager {
    static let shared = OverlayManager()

    private var window: OverlayPanel?
    private var vibeLabelWindow: NSPanel?
    private var vibeLabelTitle: String?
    private var vibeLabelHideWorkItem: DispatchWorkItem?
    private var visibilityManager = OverlayVisibilityManager()
    private var pendingHideWorkItem: DispatchWorkItem?
    private var moveObserver: NSObjectProtocol?
    private var screenParamsObserver: NSObjectProtocol?

    private let hideAnimationCompletionDelay: TimeInterval = 0.5
    private let clampOriginThreshold: CGFloat = 0.5
    private let vibeLabelExitDuration: TimeInterval = 0.24

    private let motionController = OverlayMotionController(panelEdgeInset: RecordingOverlay.panelEdgeInset)
    private let screenPersistence = OverlayScreenPersistence(panelEdgeInset: RecordingOverlay.panelEdgeInset)

    func show(
        recorder: AudioRecorder,
        isTranscribing: Bool = false,
        selectedVibeTitle: String? = nil
    ) {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil
        let panelWasVisible = window?.isVisible ?? false

        if window == nil {
            let panelSize = RecordingOverlay.panelSize
            let panel = OverlayPanel(
                contentRect: NSRect(origin: .zero, size: panelSize),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = true
            configurePanelCallbacks(panel)

            let contentView = NSHostingView(rootView: RecordingOverlay(
                recorder: recorder,
                isTranscribing: isTranscribing,
                visibilityManager: visibilityManager
            ))
            panel.contentView = contentView
            registerMoveObserverIfNeeded(for: panel)
            registerScreenParamsObserverIfNeeded(for: panel)
            window = panel
        }

        window?.contentView = NSHostingView(rootView: RecordingOverlay(
            recorder: recorder,
            isTranscribing: isTranscribing,
            visibilityManager: visibilityManager
        ))

        visibilityManager.shouldDismiss = false
        if !panelWasVisible {
            visibilityManager.isVisible = false
        }

        if let panel = window {
            resizePanel(panel, to: RecordingOverlay.panelSize)
            configurePanelCallbacks(panel)
            panel.setFrameOrigin(screenPersistence.resolvedOriginForShow(panel: panel))
            panel.orderFrontRegardless()
            updateVibeLabelWindow(title: selectedVibeTitle, relativeTo: panel)
        }

        if panelWasVisible {
            visibilityManager.isVisible = true
        } else {
            DispatchQueue.main.async { [weak self] in
            self?.visibilityManager.isVisible = true
        }
    }
    }

    func showVibePill(
        title: String,
        state: LogoBarView.VibePillState = .normal,
        duration: TimeInterval? = 0.9
    ) {
        pendingHideWorkItem?.cancel()
        pendingHideWorkItem = nil
        let panelWasVisible = window?.isVisible ?? false

        if window == nil {
            let panel = OverlayPanel(
                contentRect: NSRect(origin: .zero, size: LogoBarView.vibePillPanelSize),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.isMovableByWindowBackground = true
            configurePanelCallbacks(panel)
            registerMoveObserverIfNeeded(for: panel)
            registerScreenParamsObserverIfNeeded(for: panel)
            window = panel
        }

        if let panel = window {
            resizePanel(panel, to: LogoBarView.vibePillPanelSize)
            hideVibeLabelWindow()
            panel.contentView = NSHostingView(rootView: VibePillOverlay(
                title: title,
                state: state,
                visibilityManager: visibilityManager
            ))
            configurePanelCallbacks(panel)
            if !panelWasVisible {
                panel.setFrameOrigin(screenPersistence.resolvedOriginForShow(panel: panel))
            }
            panel.orderFrontRegardless()
        }

        visibilityManager.shouldDismiss = false
        visibilityManager.isHandsFreeLocked = false
        visibilityManager.isHandsFreeModifierPreviewActive = false
        if !panelWasVisible {
            visibilityManager.isVisible = false
        }

        DispatchQueue.main.async { [weak self] in
            self?.visibilityManager.isVisible = true
        }

        if let duration {
            let workItem = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            pendingHideWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        }
    }

    func setHandsFreeLocked(_ isLocked: Bool) {
        visibilityManager.isHandsFreeLocked = isLocked
    }

    func setHandsFreeModifierPreviewActive(_ isActive: Bool) {
        visibilityManager.isHandsFreeModifierPreviewActive = isActive
    }

    func hide() {
        pendingHideWorkItem?.cancel()
        motionController.cancelPendingMotionAnimations(panel: window)
        hideVibeLabelWindow()

        visibilityManager.isHandsFreeLocked = false
        visibilityManager.isHandsFreeModifierPreviewActive = false
        visibilityManager.isVisible = false
        visibilityManager.shouldDismiss = true

        let workItem = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
            self?.pendingHideWorkItem = nil
        }
        pendingHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + hideAnimationCompletionDelay, execute: workItem)
    }

    private func configurePanelCallbacks(_ panel: OverlayPanel) {
        panel.dragVelocitySamplingWindow = motionController.flingVelocitySamplingWindow
        panel.onDragBegan = { [weak self, weak panel] in
            self?.motionController.cancelPendingMotionAnimations(panel: panel)
        }
        panel.onDoubleClick = { [weak self, weak panel] in
            self?.moveToDefaultPosition(panel, animated: true)
        }
        panel.onDragReleaseVelocity = { [weak self, weak panel] velocity in
            self?.handleFlingRelease(panel, velocity: velocity)
        }
    }

    private func resizePanel(_ panel: NSPanel, to size: CGSize) {
        guard panel.frame.size != size else { return }
        var frame = panel.frame
        let center = NSPoint(x: frame.midX, y: frame.midY)
        frame.size = size
        frame.origin = NSPoint(
            x: center.x - (size.width / 2),
            y: center.y - (size.height / 2)
        )
        panel.setFrame(frame, display: true, animate: true)
    }

    private func handleFlingRelease(_ panel: NSPanel?, velocity: CGVector) {
        guard let panel else { return }
        let center = NSPoint(x: panel.frame.midX, y: panel.frame.midY)
        guard let screen = screenPersistence.screenContaining(point: center) ?? panel.screen ?? NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        motionController.handleFlingRelease(panel: panel, velocity: velocity, screen: screen) { [weak self] movedPanel in
            self?.screenPersistence.persistPanelLocation(movedPanel)
        }
    }

    private func registerMoveObserverIfNeeded(for panel: NSPanel) {
        guard moveObserver == nil else { return }
        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.handlePanelMove(panel)
        }
    }

    private func registerScreenParamsObserverIfNeeded(for panel: NSPanel) {
        guard screenParamsObserver == nil else { return }
        screenParamsObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak panel] _ in
            guard let self, let panel else { return }
            self.handleScreenParametersChanged(for: panel)
        }
    }

    private func handlePanelMove(_ panel: NSPanel) {
        guard !motionController.isProgrammaticMotionInFlight else {
            return
        }
        screenPersistence.persistPanelLocation(panel)
    }

    private func handleScreenParametersChanged(for panel: NSPanel) {
        screenPersistence.handleScreenParametersChanged(for: panel, clampOriginThreshold: clampOriginThreshold)
        positionVibeLabelWindow(relativeTo: panel)
    }

    private func moveToDefaultPosition(_ panel: NSPanel?, animated: Bool) {
        guard let panel else { return }
        let target = screenPersistence.defaultOrigin(for: panel)

        motionController.moveToDefaultPosition(panel: panel, target: target, animated: animated) { [weak self] movedPanel in
            self?.positionVibeLabelWindow(relativeTo: movedPanel)
            self?.screenPersistence.persistPanelLocation(movedPanel)
        }
    }

    private func updateVibeLabelWindow(title: String?, relativeTo panel: NSPanel) {
        guard let title, title.isEmpty == false else {
            hideVibeLabelWindow()
            return
        }

        let labelPanel = vibeLabelWindow ?? makeVibeLabelWindow()
        let shouldFadeIn = vibeLabelTitle != title || !labelPanel.isVisible || labelPanel.alphaValue < 1
        vibeLabelHideWorkItem?.cancel()
        vibeLabelHideWorkItem = nil
        vibeLabelTitle = title
        vibeLabelWindow = labelPanel
        attachVibeLabelWindow(labelPanel, to: panel)
        if shouldFadeIn {
            labelPanel.contentView = NSHostingView(rootView: SelectedVibeLabel(title: title))
        }
        positionVibeLabelWindow(relativeTo: panel)
        if shouldFadeIn {
            labelPanel.alphaValue = 1
        }
        labelPanel.orderFrontRegardless()
    }

    private func makeVibeLabelWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: SelectedVibeLabel.panelSize),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        return panel
    }

    private func attachVibeLabelWindow(_ labelPanel: NSPanel, to parentPanel: NSPanel) {
        guard labelPanel.parent !== parentPanel else { return }
        labelPanel.parent?.removeChildWindow(labelPanel)
        parentPanel.addChildWindow(labelPanel, ordered: .above)
    }

    private func positionVibeLabelWindow(relativeTo panel: NSPanel) {
        guard let vibeLabelWindow else { return }
        let labelSize = SelectedVibeLabel.panelSize
        vibeLabelWindow.setFrame(
            NSRect(
                x: panel.frame.midX - (labelSize.width / 2),
                y: panel.frame.minY - 3,
                width: labelSize.width,
                height: labelSize.height
            ),
            display: true
        )
    }

    private func hideVibeLabelWindow() {
        vibeLabelTitle = nil
        guard let panel = vibeLabelWindow, panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = vibeLabelExitDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
        }

        let workItem = DispatchWorkItem { [weak panel] in
            panel?.orderOut(nil)
        }
        vibeLabelHideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + vibeLabelExitDuration, execute: workItem)
    }

}
