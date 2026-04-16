import SwiftUI

extension HomeTabView {
    private enum TTSTranscriptLayout {
        static let maximumExpandedHeight: CGFloat = 300
        static let cardAnimationDuration = 0.14
        static let revealDelayNanoseconds: UInt64 = 100_000_000
        static let collapseContentDuration = 0.20

    }

    var ttsTranscriptToggleButton: some View {
        Button {
            setTTSTranscriptExpanded(!isTTSTranscriptExpanded)
        } label: {
            ZStack {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.yellow)
                    .opacity(isTTSTranscriptExpanded ? 0 : 1)

                Image(systemName: "text.alignleft")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)
                    .opacity(isTTSTranscriptExpanded ? 1 : 0)
            }
            .frame(width: 24, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.22), value: isTTSTranscriptExpanded)
    }

    var ttsTranscriptPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                Text(currentPlaybackTranscriptText)
                    .font(.appFont(18, variant: .light))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
            .id(currentPlaybackTranscriptScrollID)
            .scrollIndicators(.hidden)
            .frame(maxHeight: TTSTranscriptLayout.maximumExpandedHeight, alignment: .top)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                    .fill(AppTheme.rowFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                            .stroke(AppTheme.rowStroke, lineWidth: 1)
                    )
            )
            .overlay(alignment: .topTrailing) {
                Button {
                    ttsTranscriptCopyFeedback.copy(currentPlaybackTranscriptText, appHaptics: appHaptics)
                } label: {
                    Image(systemName: ttsTranscriptCopyFeedback.didCopy ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 18, weight: ttsTranscriptCopyFeedback.didCopy ? .bold : .medium))
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.trailing, 4)
                .animation(.easeInOut(duration: 0.18), value: ttsTranscriptCopyFeedback.didCopy)
            }
            .opacity(isTTSTranscriptPanelContentVisible ? 1 : 0)
            .compositingGroup()

            if showsTTSTranscriptIdleCloseButton {
                Button {
                    setTTSTranscriptExpanded(false)
                } label: {
                    Text("Close")
                        .font(.appFont(13, variant: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
                .opacity(isTTSTranscriptPanelContentVisible ? 1 : 0)
            }
        }
        .padding(.top, 2)
        .clipped()
    }

    var showsTTSTranscriptToggle: Bool {
        (ttsManager.isActive || ttsManager.state == .preparing || ttsManager.state == .generating)
            && currentPlaybackTranscriptText.isEmpty == false
    }

    var showsExpandedTTSTranscript: Bool {
        showsTTSTranscriptPanelContainer
    }

    var shouldShowExpandedTTSTranscriptPanel: Bool {
        isTTSTranscriptExpanded
            && currentPlaybackTranscriptText.isEmpty == false
            && (
                isTTSPreparationPresentationActive == false
                || showsTTSPreparationProgress
                || showsTTSTranscriptPanelContainer
                || isTTSTranscriptPanelContentVisible
            )
    }

    var showsTTSTranscriptIdleCloseButton: Bool {
        showsExpandedTTSTranscript && !showsTTSTranscriptToggle
    }

    var currentPlaybackTranscriptText: String {
        ttsManager.currentPlaybackDisplayText ?? ""
    }

    var currentPlaybackTranscriptScrollID: UUID? {
        ttsManager.activeRequest?.id ?? ttsManager.lastReplayableRequest?.id
    }

    func setTTSTranscriptExpanded(_ isExpanded: Bool) {
        guard isTTSTranscriptExpanded != isExpanded else { return }
        isTTSTranscriptExpanded = isExpanded
    }

    func syncTTSTranscriptPresentation() {
        ttsTranscriptRevealTask?.cancel()
        ttsTranscriptCollapseTask?.cancel()
        showsTTSTranscriptPanelContainer = shouldShowExpandedTTSTranscriptPanel
        isTTSTranscriptPanelContentVisible = shouldShowExpandedTTSTranscriptPanel
    }

    func updateTTSTranscriptPresentation() {
        ttsTranscriptRevealTask?.cancel()
        ttsTranscriptCollapseTask?.cancel()

        if shouldShowExpandedTTSTranscriptPanel {
            if showsTTSTranscriptPanelContainer == false {
                isTTSTranscriptPanelContentVisible = false
                withAnimation(.easeInOut(duration: TTSTranscriptLayout.cardAnimationDuration)) {
                    showsTTSTranscriptPanelContainer = true
                }
            }

            ttsTranscriptRevealTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: TTSTranscriptLayout.revealDelayNanoseconds)
                guard Task.isCancelled == false else { return }

                withAnimation(.easeInOut(duration: TTSTranscriptLayout.cardAnimationDuration)) {
                    isTTSTranscriptPanelContentVisible = true
                }
            }
            return
        }

        withAnimation(.easeInOut(duration: TTSTranscriptLayout.collapseContentDuration)) {
            isTTSTranscriptPanelContentVisible = false
        }

        ttsTranscriptCollapseTask = Task { @MainActor in
            try? await Task.sleep(
                nanoseconds: UInt64(TTSTranscriptLayout.cardAnimationDuration * 1_000_000_000)
            )
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: TTSTranscriptLayout.cardAnimationDuration)) {
                showsTTSTranscriptPanelContainer = false
            }
        }
    }
}
