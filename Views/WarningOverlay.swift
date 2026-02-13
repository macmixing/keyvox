import SwiftUI
import AppKit

enum WarningKind {
    case microphoneSilence
    case accessibilityPermission

    var iconName: String {
        switch self {
        case .microphoneSilence:
            return "mic.slash.fill"
        case .accessibilityPermission:
            return "accessibility"
        }
    }

    var title: String {
        switch self {
        case .microphoneSilence:
            return "No microphone audio detected"
        case .accessibilityPermission:
            return "Accessibility access required"
        }
    }

    var message: String {
        switch self {
        case .microphoneSilence:
            return "Your microphone may be muted. Check System Settings or switch the input device in KeyVox Settings."
        case .accessibilityPermission:
            return "KeyVox needs Accessibility access to paste dictation into other apps. Enable it in System Settings, then try again."
        }
    }

    var settingsTab: SettingsTab {
        switch self {
        case .microphoneSilence:
            return .audio
        case .accessibilityPermission:
            return .general
        }
    }

    var systemSettingsURL: URL? {
        switch self {
        case .microphoneSilence:
            return URL(string: "x-apple.systempreferences:com.apple.preference.sound?Input")
        case .accessibilityPermission:
            return URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        }
    }
}

struct WarningOverlay: View {
    let kind: WarningKind
    let openSystemSettings: () -> Void
    let openKeyVoxSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: kind.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.yellow)
                Text(kind.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text(kind.message)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)

            if case .microphoneSilence = kind {
                HStack(spacing: 8) {
                    Button("System Settings", action: openSystemSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button("KeyVox Settings", action: openKeyVoxSettings)
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                }
            } else {
                HStack {
                    Spacer(minLength: 0)
                    Button("System Settings", action: openSystemSettings)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Spacer(minLength: 0)
                }
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
            rootView: WarningOverlay(
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
