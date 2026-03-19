import AppKit
import Combine
import CoreGraphics
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
    private var visibilityManager = OverlayVisibilityManager()
    private var pendingHideWorkItem: DispatchWorkItem?
    private var moveObserver: NSObjectProtocol?
    private var screenParamsObserver: NSObjectProtocol?

    private let hideAnimationCompletionDelay: TimeInterval = 0.5
    private let clampOriginThreshold: CGFloat = 0.5

    private let motionController = OverlayMotionController(panelEdgeInset: RecordingOverlay.panelEdgeInset)
    private let screenPersistence = OverlayScreenPersistence(panelEdgeInset: RecordingOverlay.panelEdgeInset)

    func show(recorder: AudioRecorder, isTranscribing: Bool = false) {
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
            configurePanelCallbacks(panel)
            panel.setFrameOrigin(screenPersistence.resolvedOriginForShow(panel: panel))
            panel.orderFrontRegardless()
        }

        if panelWasVisible {
            visibilityManager.isVisible = true
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.visibilityManager.isVisible = true
            }
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
    }

    private func moveToDefaultPosition(_ panel: NSPanel?, animated: Bool) {
        guard let panel else { return }
        let target = screenPersistence.defaultOrigin(for: panel)

        motionController.moveToDefaultPosition(panel: panel, target: target, animated: animated) { [weak self] movedPanel in
            self?.screenPersistence.persistPanelLocation(movedPanel)
        }
    }
}
