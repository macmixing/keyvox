import Foundation
import SwiftUI
import AppKit

struct SettingsLastTranscriptionCard: View {
    let text: String

    @State private var didCopy = false
    @State private var copyResetTask: Task<Void, Never>?

    private var trimmedText: String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    var body: some View {
        SettingsCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    Text("Last Transcription", comment: "Heading of the Settings card that shows the most recent dictated text.")
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

                        Text("Your last transcription will appear here after you dictate on this Mac.", comment: "Empty state text in the Last Transcription card in Settings.")
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
        .onDisappear {
            copyResetTask?.cancel()
            copyResetTask = nil
        }
    }

    private func copyButton(for text: String) -> some View {
        AppActionButton(
            title: didCopy ? String(localized: "Copied", comment: "Button title in the Last Transcription card after the text was copied.") : String(localized: "Copy", comment: "Button in the Last Transcription card that copies the text."),
            style: .primary,
            minWidth: 84
        ) {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            didCopy = true
            copyResetTask?.cancel()

            copyResetTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.2))
                guard !Task.isCancelled else { return }
                didCopy = false
                copyResetTask = nil
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
