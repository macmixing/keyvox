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
            if showsTTSTranscriptIdleCloseButton {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isTTSTranscriptExpanded = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
                .padding(.trailing, 2)
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
