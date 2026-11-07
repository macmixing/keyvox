import SwiftUI
import AppKit

private enum UpdatePromptLayout {
    static let width: CGFloat = 430
    static let fallbackHeight: CGFloat = 280
    static let shellPadding = EdgeInsets(top: 20, leading: 24, bottom: 30, trailing: 24)
}

struct UpdatePromptOverlay: View {
    private struct MessageWidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    let prompt: UpdatePrompt
    let onPrimaryAction: () -> Void
    let onDismiss: () -> Void

    @State private var messageWidth: CGFloat = 0

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
                    StatusBadge(title: versionBadgeTitle, backgroundColor: MacAppTheme.accent)
                }
            }

            VStack(alignment: .center, spacing: 8) {
                Text(prompt.title)
                    .font(.appFont(19))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(prompt.message)
                    .font(.appFont(12, variant: .light))
                    .foregroundColor(.secondary)
                    .lineSpacing(0.5)
                    .multilineTextAlignment(.center)
                    .truncationMode(.tail)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: MessageWidthPreferenceKey.self,
                                value: geometry.size.width
                            )
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .onPreferenceChange(MessageWidthPreferenceKey.self) { width in
                messageWidth = width
            }

            if let progress = prompt.progress {
                LabeledProgressBar(
                    progress: min(max(progress.value, 0), 1),
                    statusText: progress.statusText
                )
                .frame(maxWidth: messageWidth > 0 ? messageWidth : .infinity)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                actionButtons
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(UpdatePromptLayout.shellPadding)
        .frame(width: UpdatePromptLayout.width)
        .background(
            ZStack {
                VisualEffectView(material: .menu, blendingMode: .behindWindow)
                MacAppTheme.screenBackground
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(MacAppTheme.windowStroke, lineWidth: 0.7)
        )
        .preferredColorScheme(.dark)
    }

    private var actionButtons: some View {
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
}

@MainActor
final class UpdatePromptManager {
    static let shared = UpdatePromptManager()
    private var window: NSPanel?
    private var hostingView: NSHostingView<UpdatePromptOverlay>?
    private var panelQueue = UpdatePromptPanelQueue()

    func show(prompt: UpdatePrompt) {
        guard panelQueue.shouldShow(prompt, isPanelVisible: window?.isVisible == true) else {
            return
        }

        if window == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: UpdatePromptLayout.width, height: UpdatePromptLayout.fallbackHeight),
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

        let overlay = makeOverlay(for: prompt)

        // A prompt that is already on screen changes its content in place.
        if let window, window.isVisible, let hostingView {
            hostingView.rootView = overlay
            resizeKeepingTopEdge(window, to: resolvedContentSize(for: hostingView))
            return
        }

        let hostingView = NSHostingView(rootView: overlay)
        self.hostingView = hostingView
        let contentSize = resolvedContentSize(for: hostingView)
        hostingView.frame = NSRect(origin: .zero, size: contentSize)
        window?.contentView = hostingView
        window?.setContentSize(contentSize)
        centerPromptWindow()

        window?.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
        if let queuedPrompt = panelQueue.takeQueuedPrompt() {
            show(prompt: queuedPrompt)
        }
    }

    private func resolvedContentSize(for hostingView: NSHostingView<UpdatePromptOverlay>) -> NSSize {
        let fittingSize = hostingView.fittingSize
        guard fittingSize.width > 0, fittingSize.height > 0 else {
            return NSSize(width: UpdatePromptLayout.width, height: UpdatePromptLayout.fallbackHeight)
        }

        return fittingSize
    }

    private func resizeKeepingTopEdge(_ window: NSWindow, to contentSize: NSSize) {
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize))
        frame.origin.x = window.frame.minX
        frame.origin.y = window.frame.maxY - frame.height
        window.setFrame(frame, display: true, animate: false)
    }

    private func makeOverlay(for prompt: UpdatePrompt) -> UpdatePromptOverlay {
        UpdatePromptOverlay(
            prompt: prompt,
            onPrimaryAction: {
                prompt.onPrimaryAction?()
                if prompt.dismissesOnPrimaryAction {
                    UpdatePromptManager.shared.hide()
                }
            },
            onDismiss: {
                prompt.onDismiss()
                UpdatePromptManager.shared.hide()
            }
        )
    }

    private func centerPromptWindow() {
        guard let window else { return }
        let screen = AppUpdateDisplayCoordinator.shared.preferredScreen(for: window)
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
