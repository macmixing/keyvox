import SwiftUI
import AppKit

struct SettingsLastTranscriptionCard: View {
    let text: String

    @State private var didCopy = false

    private var trimmedText: String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Last Transcription")
                        .font(.appFont(17))

                    Spacer(minLength: 0)

                    if let trimmedText {
                        copyButton(for: trimmedText)
                    }
                }

                if let trimmedText {
                    Text(trimmedText)
                        .font(.appFont(16, variant: .light))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .padding(16)
                        .background(innerContainer)
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "waveform.and.mic")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.yellow)

                        Text("Your last transcription will appear here after you dictate on this Mac.")
                            .font(.appFont(14, variant: .light))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(16)
                    .background(innerContainer)
                }
            }
        }
    }

    private func copyButton(for text: String) -> some View {
        AppActionButton(
            title: didCopy ? "Copied" : "Copy",
            style: .primary,
            minWidth: 84
        ) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            didCopy = true

            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                didCopy = false
            }
        }
    }

    private var innerContainer: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(.white.opacity(0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(MacAppTheme.cardStroke, lineWidth: 1)
            )
    }
}
