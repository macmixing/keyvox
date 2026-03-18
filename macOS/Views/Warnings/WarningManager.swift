import AppKit
import QuartzCore
import SwiftUI

@MainActor
final class WarningManager {
    static let shared = WarningManager()
    private var window: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var autoDismissWorkItem: DispatchWorkItem?
    private var hoverExitDismissWorkItem: DispatchWorkItem?
    private var isWarningHovered: Bool = false
    private var warningPresentationID: UInt = 0
    private let autoDismissDelay: TimeInterval = 6.0
    private let hoverExitDismissDelay: TimeInterval = 2.0
    private let dismissAnimationDuration: TimeInterval = 0.42
    private let dismissSlideDistance: CGFloat = 64
    private var recoveryWindow: NSPanel?
    private var recoveryModel: PasteFailureRecoveryOverlayModel?
    private var recoveryPresentationID: UInt = 0

    func show(_ kind: WarningKind) {
        playCancelSound()
        cancelDismissSchedules()
        isWarningHovered = false
        warningPresentationID &+= 1
        let currentPresentationID = warningPresentationID

        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 130),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovable = false
            panel.isMovableByWindowBackground = false
            window = panel
        }

        let contentView = WarningTrackingHostingView(
            rootView: WarningOverlayView(
                kind: kind,
                openSystemSettings: {
                    if let url = kind.systemSettingsURL {
                        NSWorkspace.shared.open(url)
                    }
                    WarningManager.shared.hide()
                },
                openKeyVoxSettings: {
                    Task { @MainActor in
                        WindowManager.shared.openSettings(tab: kind.settingsTab)
                        WarningManager.shared.hide()
                    }
                }
            )
        )
        contentView.hoverChanged = { [weak self] isHovered in
            self?.handleWarningHoverChanged(isHovered, presentationID: currentPresentationID)
        }
        window?.contentView = contentView

        if let screen = NSScreen.main {
            let rect = screen.visibleFrame
            window?.setFrameOrigin(NSPoint(x: rect.midX - 130, y: rect.minY + 50))
        }

        window?.alphaValue = 1
        window?.orderFrontRegardless()
        setupMonitor()
        scheduleAutoDismiss(for: currentPresentationID)
    }

    @MainActor
    func showPasteFailureRecovery(progress: Double, onDismiss: @escaping () -> Void) {
        playCancelSound()
        recoveryPresentationID &+= 1

        if recoveryWindow == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 320, height: 128),
                styleMask: [.nonactivatingPanel, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isMovable = true
            panel.isMovableByWindowBackground = true
            recoveryWindow = panel
        }

        // Recovery overlay model is main-actor isolated; construct and mutate it only on MainActor.
        let model = PasteFailureRecoveryOverlayModel(progress: progress, onDismiss: onDismiss)
        recoveryModel = model
        recoveryWindow?.contentView = NSHostingView(
            rootView: PasteFailureRecoveryOverlayView(model: model)
        )

        if let screen = NSScreen.main {
            let rect = screen.visibleFrame
            recoveryWindow?.setFrameOrigin(NSPoint(x: rect.midX - 160, y: rect.minY + 50))
        }

        recoveryWindow?.alphaValue = 1
        recoveryWindow?.orderFrontRegardless()
    }

    @MainActor
    func updatePasteFailureRecovery(progress: Double) {
        recoveryModel?.progress = max(0, min(1, progress))
    }

    @MainActor
    func hidePasteFailureRecovery() {
        hidePasteFailureRecoveryWithDismissTransition(expectedPresentationID: nil)
    }

    private func playCancelSound() {
        let appSettings = AppSettingsStore.shared
        guard appSettings.isSoundEnabled else { return }
        // Keep warning cues tied to the global cue-volume preference.
        if let sound = NSSound(named: "Submarine") {
            sound.volume = Float(appSettings.soundVolume)
            sound.play()
        }
    }

    private func setupMonitor() {
        // Dismiss warnings on click-away both inside and outside app focus.
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, let window = self.window, window.isVisible else { return event }
                if !window.frame.contains(NSEvent.mouseLocation) {
                    self.hide()
                }
                return event
            }
        }

        if globalMonitor == nil {
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                self?.hide()
            }
        }
    }

    func hide() {
        hideWithDismissTransition(expectedPresentationID: nil)
    }

    private func removeWarningDismissMonitors() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
            globalMonitor = nil
        }
    }

    private func scheduleAutoDismiss(for presentationID: UInt) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if self.isWarningHovered {
                return
            }
            self.hideWithDismissTransition(expectedPresentationID: presentationID)
        }
        autoDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay, execute: workItem)
    }

    private func cancelAutoDismiss() {
        autoDismissWorkItem?.cancel()
        autoDismissWorkItem = nil
    }

    private func scheduleHoverExitDismiss(for presentationID: UInt) {
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            guard !self.isWarningHovered else { return }
            self.hideWithDismissTransition(expectedPresentationID: presentationID)
        }
        hoverExitDismissWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + hoverExitDismissDelay, execute: workItem)
    }

    private func cancelHoverExitDismiss() {
        hoverExitDismissWorkItem?.cancel()
        hoverExitDismissWorkItem = nil
    }

    private func cancelDismissSchedules() {
        cancelAutoDismiss()
        cancelHoverExitDismiss()
    }

    private func handleWarningHoverChanged(_ isHovered: Bool, presentationID: UInt) {
        guard presentationID == warningPresentationID else { return }
        isWarningHovered = isHovered

        if isHovered {
            cancelAutoDismiss()
            cancelHoverExitDismiss()
        } else {
            cancelHoverExitDismiss()
            scheduleHoverExitDismiss(for: presentationID)
        }
    }

    private func hideWithDismissTransition(expectedPresentationID: UInt?) {
        dismissPanelWithTransition(
            panel: window,
            expectedPresentationID: expectedPresentationID,
            currentPresentationID: warningPresentationID,
            isCurrentPresentation: { [weak self] presentationID in
                presentationID == self?.warningPresentationID
            },
            prepareForDismiss: { [weak self] in
                self?.cancelDismissSchedules()
                self?.isWarningHovered = false
            },
            handleMissingPanel: { [weak self] in
                self?.removeWarningDismissMonitors()
            },
            handlePanelNotVisible: { [weak self] in
                self?.removeWarningDismissMonitors()
            },
            completeDismiss: { [weak self] in
                self?.removeWarningDismissMonitors()
            }
        )
    }

    private func hidePasteFailureRecoveryWithDismissTransition(expectedPresentationID: UInt?) {
        dismissPanelWithTransition(
            panel: recoveryWindow,
            expectedPresentationID: expectedPresentationID,
            currentPresentationID: recoveryPresentationID,
            isCurrentPresentation: { [weak self] presentationID in
                presentationID == self?.recoveryPresentationID
            },
            handleMissingPanel: { [weak self] in
                self?.recoveryModel = nil
            },
            handlePanelNotVisible: { [weak self] in
                self?.recoveryModel = nil
            },
            completeDismiss: { [weak self] in
                self?.recoveryModel = nil
            }
        )
    }

    private func dismissPanelWithTransition(
        panel: NSPanel?,
        expectedPresentationID: UInt?,
        currentPresentationID: UInt,
        isCurrentPresentation: @escaping (UInt) -> Bool,
        prepareForDismiss: () -> Void = {},
        handleMissingPanel: () -> Void = {},
        handlePanelNotVisible: () -> Void = {},
        completeDismiss: @escaping () -> Void
    ) {
        if let expectedPresentationID, !isCurrentPresentation(expectedPresentationID) {
            return
        }

        prepareForDismiss()

        guard let panel else {
            handleMissingPanel()
            return
        }

        guard panel.isVisible else {
            panel.alphaValue = 1
            handlePanelNotVisible()
            return
        }

        let startFrame = panel.frame
        var endFrame = startFrame
        endFrame.origin.y -= dismissSlideDistance
        let dismissingPresentationID = currentPresentationID

        NSAnimationContext.runAnimationGroup { context in
            context.duration = dismissAnimationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(endFrame, display: false)
            panel.animator().alphaValue = 0
        } completionHandler: {
            // If a newer overlay started while this one was animating out, do not mutate it.
            guard isCurrentPresentation(dismissingPresentationID) else { return }
            panel.orderOut(nil)
            panel.setFrame(startFrame, display: false)
            panel.alphaValue = 1
            completeDismiss()
        }
    }
}

private final class WarningTrackingHostingView: NSHostingView<WarningOverlayView> {
    var hoverChanged: ((Bool) -> Void)?
    private var trackingAreaRef: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.activeAlways, .inVisibleRect, .mouseEnteredAndExited],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        trackingAreaRef = trackingArea
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        hoverChanged?(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        hoverChanged?(false)
    }
}
