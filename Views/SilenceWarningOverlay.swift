import SwiftUI

struct SilenceWarningOverlay: View {
    let openSystemSettings: () -> Void
    let openKeyVoxAudioSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "mic.slash.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.yellow)
                Text("No microphone audio detected")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text("Your microphone may be muted. Check System Settings or switch the input device in KeyVox Settings.")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            HStack(spacing: 8) {
                Button("System Settings") {
                    openSystemSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("KeyVox Settings") {
                    openKeyVoxAudioSettings()
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 260)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.06)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }
}

class SilenceWarningManager {
    static let shared = SilenceWarningManager()
    private var window: NSPanel?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    func show() {
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
            panel.isMovableByWindowBackground = false // NON MOVABLE

            window = panel
        }

        window?.contentView = NSHostingView(rootView: SilenceWarningOverlay(
            openSystemSettings: {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.sound?Input") {
                    NSWorkspace.shared.open(url)
                }
                SilenceWarningManager.shared.hide()
            },
            openKeyVoxAudioSettings: {
                WindowManager.shared.openSettings(tab: .audio)
                SilenceWarningManager.shared.hide()
            }
        ))

        if let screen = NSScreen.main {
            let rect = screen.visibleFrame
            window?.setFrameOrigin(NSPoint(x: rect.midX - 130, y: rect.minY + 50))
        }

        window?.orderFrontRegardless()
        
        setupMonitor()
    }

    private func setupMonitor() {
        // Ensure we don't duplicate monitors
        if localMonitor == nil {
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, let window = self.window, window.isVisible else { return event }
                
                // If click is outside the window, hide it
                // Convert mouse location to window coordinates to check if it's inside
                let mouseLocation = NSEvent.mouseLocation
                if !window.frame.contains(mouseLocation) {
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
