import AppKit
import SwiftUI

final class WarningManager {
    static let shared = WarningManager()
    private var window: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?

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
                    WindowManager.shared.openSettings(tab: kind.settingsTab)
                    WarningManager.shared.hide()
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

    private func playCancelSound() {
        guard KeyboardMonitor.shared.isSoundEnabled else { return }
        if let sound = NSSound(named: "Bottle") {
            sound.volume = 0.1
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
