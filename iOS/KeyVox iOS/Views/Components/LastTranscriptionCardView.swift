import SwiftUI
import UIKit

struct LastTranscriptionCardView: View {
    let text: String?
    let isLoading: Bool

    @State private var didCopy = false

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
                    } else if let transcriptionText {
                        Text(transcriptionText)
                            .font(.appFont(18, variant: .light))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
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
                    }
                }
                .padding(16)
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

    @ViewBuilder
    private func copyButton(for text: String) -> some View {
        AppActionButton(
            title: "Copy",
            systemImage: didCopy ? "checkmark" : "doc.on.doc",
            systemImageColor: didCopy ? .black : nil,
            systemImageWeight: didCopy ? .black : .regular,
            style: .primary,
            minWidth: 84,
            size: .compact,
            fontSize: 15
        ) {
            UIPasteboard.general.string = text
            didCopy = true

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                didCopy = false
            }
        }
    }
}
