import SwiftUI

struct LastTranscriptionCardView: View {
    let text: String?
    let isLoading: Bool

    private enum Layout {
        static let maximumExpandedHeight: CGFloat = 300
        static let contentPadding: CGFloat = 16
        static let copyButtonSize: CGFloat = 32
        static let minimumExpandedHeight = copyButtonSize + (contentPadding * 2)
    }

    @Environment(\.appHaptics) private var appHaptics
    @StateObject private var copyFeedback = CopyFeedbackController()

    private var transcriptionText: String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isLoading ? "Processing..." : "Latest Transcription")
                            .font(.appFont(17))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 0)

                    if let transcriptionText, !isLoading {
                        copyButton(for: transcriptionText)
                    }
                }

                Group {
                    if isLoading {
                        HStack {
                            Spacer(minLength: 0)
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70)
                        .padding(Layout.contentPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                                .fill(AppTheme.rowFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                                        .stroke(AppTheme.rowStroke, lineWidth: 1)
                                )
                        )
                    } else if let transcriptionText {
                        AppTintedScrollView(
                            contentPadding: Layout.contentPadding,
                            minimumHeight: Layout.minimumExpandedHeight,
                            maximumHeight: Layout.maximumExpandedHeight
                        ) {
                            Text(transcriptionText)
                                .font(.appFont(18, variant: .light))
                                .foregroundStyle(.white)
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: Layout.copyButtonSize,
                                    alignment: isSingleLine(transcriptionText) ? .leading : .topLeading
                                )
                                .multilineTextAlignment(.leading)
                                .textSelection(.enabled)
                        }
                        .id(transcriptionText)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                                .fill(AppTheme.rowFill)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                                .stroke(AppTheme.rowStroke, lineWidth: 1)
                        )
                    } else {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "waveform.and.mic")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.yellow)

                            Text("Your last transcription will appear here after you dictate on this device.")
                                .font(.appFont(14))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .multilineTextAlignment(.leading)
                        }
                        .padding(Layout.contentPadding)
                        .background(
                            RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                                .fill(AppTheme.rowFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppTheme.rowCornerRadius)
                                        .stroke(AppTheme.rowStroke, lineWidth: 1)
                                )
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func copyButton(for text: String) -> some View {
        AppActionButton(
            title: "Copy",
            systemImage: copyFeedback.didCopy ? "checkmark" : "doc.on.doc",
            systemImageColor: copyFeedback.didCopy ? .black : nil,
            systemImageWeight: copyFeedback.didCopy ? .black : .regular,
            style: .primary,
            minWidth: 84,
            size: .compact,
            fontSize: 15
        ) {
            copyFeedback.copy(text, appHaptics: appHaptics)
        }
    }

    private func isSingleLine(_ text: String) -> Bool {
        text.rangeOfCharacter(from: .newlines) == nil
    }
}
