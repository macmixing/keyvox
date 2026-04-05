import SwiftUI

extension HomeTabView {
    var ttsTranscriptToggleButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isTTSTranscriptExpanded.toggle()
            }
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
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.82))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 180, alignment: .top)
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

            if showsTTSTranscriptIdleCloseButton {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isTTSTranscriptExpanded = false
                    }
                } label: {
                    Text("Close")
                        .font(.appFont(13, variant: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 2)
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98, anchor: .top)),
                removal: .opacity
            )
        )
    }

    var showsTTSTranscriptToggle: Bool {
        (ttsManager.isActive || ttsManager.state == .preparing || ttsManager.state == .generating)
            && currentPlaybackTranscriptText.isEmpty == false
    }

    var showsExpandedTTSTranscript: Bool {
        isTTSTranscriptExpanded && currentPlaybackTranscriptText.isEmpty == false
    }

    var showsTTSTranscriptIdleCloseButton: Bool {
        showsExpandedTTSTranscript && !showsTTSTranscriptToggle
    }

    var currentPlaybackTranscriptText: String {
        ttsManager.currentPlaybackDisplayText ?? ""
    }
}
