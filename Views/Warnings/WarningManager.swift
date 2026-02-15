import AppKit
import SwiftUI

final class WarningManager {
    static let shared = WarningManager()
    private var window: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var recoveryWindow: NSPanel?
    private var recoveryModel: PasteFailureRecoveryOverlayModel?

    func show(_ kind: WarningKind) {
        playCancelSound()

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

        window?.contentView = NSHostingView(
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

        if let screen = NSScreen.main {
            let rect = screen.visibleFrame
            window?.setFrameOrigin(NSPoint(x: rect.midX - 130, y: rect.minY + 50))
        }

        window?.orderFrontRegardless()
        setupMonitor()
    }

    @MainActor
    func showPasteFailureRecovery(progress: Double, onDismiss: @escaping () -> Void) {
        playCancelSound()

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

        let model = PasteFailureRecoveryOverlayModel(progress: progress, onDismiss: onDismiss)
        recoveryModel = model
        recoveryWindow?.contentView = NSHostingView(
            rootView: PasteFailureRecoveryOverlayView(model: model)
        )

        if let screen = NSScreen.main {
            let rect = screen.visibleFrame
            recoveryWindow?.setFrameOrigin(NSPoint(x: rect.midX - 160, y: rect.minY + 50))
        }

        recoveryWindow?.orderFrontRegardless()
    }

    @MainActor
    func updatePasteFailureRecovery(progress: Double) {
        recoveryModel?.progress = max(0, min(1, progress))
    }

    @MainActor
    func hidePasteFailureRecovery() {
        recoveryWindow?.orderOut(nil)
        recoveryModel = nil
    }

    private func playCancelSound() {
        let appSettings = AppSettingsStore.shared
        guard appSettings.isSoundEnabled else { return }
        if let sound = NSSound(named: "Bottle") {
            sound.volume = Float(appSettings.soundVolume)
            sound.play()
        }
    }

    private func setupMonitor() {
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
        window?.orderOut(nil)
        removeWarningDismissMonitors()
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
}
