import SwiftUI
import AppKit

private enum UpdatePromptLayout {
    static let width: CGFloat = 430
    static let height: CGFloat = 250
    static let messageMinHeight: CGFloat = 42
    static let messageMaxHeight: CGFloat = 84
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
        VStack(alignment: .leading, spacing: 14) {
            AnimatedWaveHeader {
                if let versionBadgeTitle {
                    StatusBadge(title: versionBadgeTitle, color: .indigo)
                }
            }
            .padding(.horizontal, 8)

            VStack(alignment: .center, spacing: 8) {
                Text(prompt.title)
                    .font(.custom("Kanit Medium", size: 19))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(prompt.message)
                    .font(.custom("Kanit Medium", size: 12))
                    .foregroundColor(.secondary)
                    .lineSpacing(0.5)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)
                .frame(maxWidth: .infinity)
                .frame(
                    minHeight: UpdatePromptLayout.messageMinHeight,
                    maxHeight: UpdatePromptLayout.messageMaxHeight,
                    alignment: .center
                )
            }
            .padding(.horizontal, 8)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button(prompt.dismissButtonTitle, action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)

                if let primaryButtonTitle = prompt.primaryButtonTitle {
                    Button(primaryButtonTitle, action: onPrimaryAction)
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.regular)
                }
            }
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
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

        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let targetFrame = NSRect(
                x: visibleFrame.midX - (UpdatePromptLayout.width / 2),
                y: visibleFrame.midY - (UpdatePromptLayout.height / 2),
                width: UpdatePromptLayout.width,
                height: UpdatePromptLayout.height
            )
            window?.setFrame(targetFrame, display: false)
        }

        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }
}

extension UpdatePromptManager: UpdatePromptPresenting {}
