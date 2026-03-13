import SwiftUI
import UIKit

struct iOSLastTranscriptionCardView: View {
    let text: String?

    @State private var didCopy = false

    private var transcriptionText: String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else {
            return nil
        }
        return text
    }

    var body: some View {
        iOSAppCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Latest Transcription")
                            .font(.appFont(17))
                            .foregroundStyle(.white)

                        Text("Your most recent on-device dictation.")
                            .font(.appFont(12))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)

                    if let transcriptionText {
                        copyButton(for: transcriptionText)
                    }
                }

                Group {
                    if let transcriptionText {
                        Text(transcriptionText)
                            .font(.appFont(18))
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
                    RoundedRectangle(cornerRadius: iOSAppTheme.rowCornerRadius)
                        .fill(iOSAppTheme.rowFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: iOSAppTheme.rowCornerRadius)
                                .stroke(iOSAppTheme.rowStroke, lineWidth: 1)
                        )
                )
            }
        }
    }

    @ViewBuilder
    private func copyButton(for text: String) -> some View {
        Button {
            UIPasteboard.general.string = text
            didCopy = true

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                didCopy = false
            }
        } label: {
            Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
        }
        .font(.appFont(12))
        .buttonStyle(.borderedProminent)
        .tint(.indigo)
    }
}
