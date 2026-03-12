import SwiftUI
import AppKit

private enum UpdatePromptLayout {
    static let width: CGFloat = 430
    static let height: CGFloat = 280
    static let shellPadding = EdgeInsets(top: 20, leading: 24, bottom: 30, trailing: 24)
}

struct UpdatePromptOverlay: View {
    let prompt: UpdatePrompt
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void

    private var versionBadgeTitle: String? {
        guard let version = prompt.version, !version.isEmpty else { return nil }
        if let build = prompt.build, !build.isEmpty {
            return "v\(version) (\(build))"
        }
        return "v\(version)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            AnimatedWaveHeader {
                if let versionBadgeTitle {
                    StatusBadge(title: versionBadgeTitle, color: .indigo)
                }
            }

            VStack(alignment: .center, spacing: 8) {
                Text(prompt.title)
                    .font(.appFont(19))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(prompt.message)
                    .font(.appFont(12))
                    .foregroundColor(.secondary)
                    .lineSpacing(0.5)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                AppActionButton(
                    title: prompt.dismissButtonTitle,
                    style: .secondary,
                    minWidth: 150,
                    action: onDismiss
                )

                if let primaryButtonTitle = prompt.primaryButtonTitle {
                    AppActionButton(
                        title: primaryButtonTitle,
                        style: .primary,
                        minWidth: 150,
                        action: onPrimaryAction
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(UpdatePromptLayout.shellPadding)
        .frame(width: UpdatePromptLayout.width, height: UpdatePromptLayout.height)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                Color.indigo.opacity(0.15)
                    .background(Color(white: 0.01))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
    }
}

final class UpdatePromptManager {
    static let shared = UpdatePromptManager()
    private var window: NSPanel?

    func show(prompt: UpdatePrompt) {
        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: UpdatePromptLayout.width, height: UpdatePromptLayout.height),
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

        let hostingView = NSHostingView(
            rootView: UpdatePromptOverlay(
                prompt: prompt,
                onPrimaryAction: {
                    prompt.onPrimaryAction?()
                    UpdatePromptManager.shared.hide()
                },
                onDismiss: {
                    prompt.onDismiss()
                    UpdatePromptManager.shared.hide()
                }
            )
        )
        hostingView.frame = NSRect(x: 0, y: 0, width: UpdatePromptLayout.width, height: UpdatePromptLayout.height)
        window?.contentView = hostingView
        window?.setContentSize(NSSize(width: UpdatePromptLayout.width, height: UpdatePromptLayout.height))
        centerPromptWindow()

        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    private func centerPromptWindow() {
        guard let window else { return }
        let screen = window.screen ?? NSApp.keyWindow?.screen ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }

        let visibleFrame = screen.visibleFrame
        let windowSize = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - (windowSize.width / 2),
            y: visibleFrame.midY - (windowSize.height / 2)
        )
        window.setFrameOrigin(origin)
    }
}

extension UpdatePromptManager: UpdatePromptPresenting {}
