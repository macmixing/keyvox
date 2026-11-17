import Foundation
import SwiftUI

enum PendingDownloadConfirmation: Identifiable, Equatable {
    case dictationModel(DictationModelID)
    case keyVoxVibesAI
    case sharedTTSModel
    case ttsVoice(AppSettingsStore.TTSVoice)
    case ttsVoiceWithSharedModel(AppSettingsStore.TTSVoice)

    var id: String {
        switch self {
        case .dictationModel(let modelID):
            return "dictation-\(modelID.rawValue)"
        case .keyVoxVibesAI:
            return "keyvox-vibes-ai"
        case .sharedTTSModel:
            return "tts-shared"
        case .ttsVoice(let voice):
            return "tts-voice-\(voice.rawValue)"
        case .ttsVoiceWithSharedModel(let voice):
            return "tts-shared-voice-\(voice.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .dictationModel(let modelID):
            switch modelID {
            case .whisperBase:
                return String(localized: "Download Whisper Base?", comment: "Title of the confirmation shown before downloading a dictation model. Whisper Base is a brand name and stays in English.")
            case .parakeetTdtV3:
                return String(localized: "Download Parakeet v3?", comment: "Title of the confirmation shown before downloading a dictation model. Parakeet v3 is a brand name and stays in English.")
            }
        case .keyVoxVibesAI:
            return String(localized: "Download KeyVox Vibes AI?", comment: "Title of the confirmation shown before downloading the Vibes AI model. KeyVox Vibes AI is a brand name and stays in English.")
        case .sharedTTSModel:
            return String(localized: "Download Speak Engine?", comment: "Title of the confirmation shown before downloading the KeyVox Speak text-to-speech engine. Speak is a brand name and stays in English.")
        case .ttsVoice(let voice):
            return String(localized: "Download \(voice.displayName)'s Voice?", comment: "Title of the confirmation shown before downloading a KeyVox Speak voice. The placeholder is the voice name, which stays in English.")
        case .ttsVoiceWithSharedModel:
            return String(localized: "Download KeyVox Speak?", comment: "Title of the confirmation shown before downloading the text-to-speech engine together with a voice. KeyVox Speak is a brand name and stays in English.")
        }
    }

    var message: String {
        switch self {
        case .dictationModel(let modelID):
            switch modelID {
            case .whisperBase:
                return String(localized: "Download the Whisper Base dictation model (\(ApproximateDownloadSize.whisperBase)) before using local dictation on this device?", comment: "Message in the confirmation shown before downloading a dictation model. Whisper Base is a brand name and stays in English. The value in parentheses is the approximate download size.")
            case .parakeetTdtV3:
                return String(localized: "Download the Parakeet v3 dictation model (\(ApproximateDownloadSize.parakeet)) for faster on-device dictation on this device?", comment: "Message in the confirmation shown before downloading a dictation model. Parakeet v3 is a brand name and stays in English. The value in parentheses is the approximate download size.")
            }
        case .keyVoxVibesAI:
            return String(localized: "Download KeyVox Vibes AI (\(ApproximateDownloadSize.vibesAI)) to use KeyVox Vibes on this device?", comment: "Message in the confirmation shown before downloading the Vibes AI model. KeyVox Vibes AI and KeyVox Vibes are brand names and stay in English. The value in parentheses is the approximate download size.")
        case .sharedTTSModel:
            return String(localized: "Download the KeyVox Speak engine (\(ApproximateDownloadSize.speakEngine)) to speak copied text on this device?", comment: "Message in the confirmation shown before downloading the text-to-speech engine. KeyVox Speak is a brand name and stays in English. The value in parentheses is the approximate download size.")
        case .ttsVoice(let voice):
            return String(localized: "Download \(voice.displayName)'s voice (\(ApproximateDownloadSize.speakVoice)) to speak copied text on this device?", comment: "Message in the confirmation shown before downloading a KeyVox Speak voice. The first placeholder is the voice name, which stays in English; the second, in parentheses, is the approximate download size.")
        case .ttsVoiceWithSharedModel(let voice):
            return String(localized: "Download the KeyVox Speak engine and \(voice.displayName)'s voice (\(ApproximateDownloadSize.speakEngineAndVoice) total) to speak copied text on this device?", comment: "Message in the confirmation shown before downloading the text-to-speech engine and a voice together. KeyVox Speak is a brand name and stays in English. The first placeholder is the voice name, which stays in English; the second, in parentheses, is the approximate total download size.")
        }
    }
}

extension View {
    func downloadConfirmation(
        _ confirmation: Binding<PendingDownloadConfirmation?>,
        onConfirm: @escaping (PendingDownloadConfirmation) -> Void
    ) -> some View {
        modifier(
            DownloadConfirmationModifier(
                confirmation: confirmation,
                onConfirm: onConfirm
            )
        )
    }
}

private struct DownloadConfirmationModifier: ViewModifier {
    @Binding var confirmation: PendingDownloadConfirmation?
    let onConfirm: (PendingDownloadConfirmation) -> Void
    @AccessibilityFocusState private var isCancelFocused: Bool

    func body(content: Content) -> some View {
        content
            .accessibilityHidden(confirmation != nil)
            .overlay {
                if let confirmation {
                    ZStack {
                        Color.black.opacity(0.6)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())

                        VStack(alignment: .leading, spacing: 18) {
                            Text(confirmation.title)
                                .font(.appFont(22))
                                .foregroundStyle(.white)

                            Text(confirmation.message)
                                .font(.appFont(15, variant: .light))
                                .foregroundStyle(.white.opacity(0.78))

                            VStack(spacing: 12) {
                                AppActionButton(
                                    title: String(localized: "Download", comment: "Button in the download confirmation that starts the download."),
                                    style: .primary,
                                    fillsWidth: true,
                                    size: .regular,
                                    fontSize: 16,
                                    action: {
                                        let activeConfirmation = confirmation
                                        self.confirmation = nil
                                        onConfirm(activeConfirmation)
                                    }
                                )

                                AppActionButton(
                                    title: String(localized: "Cancel", comment: "Button that closes the download confirmation without downloading."),
                                    style: .secondary,
                                    fillsWidth: true,
                                    size: .regular,
                                    fontSize: 16,
                                    action: {
                                        self.confirmation = nil
                                    }
                                )
                                .accessibilityFocused($isCancelFocused)
                            }
                        }
                        .padding(22)
                        .frame(maxWidth: 420, alignment: .leading)
                        .background(AppTheme.screenBackground)
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.yellow.opacity(0.9), lineWidth: 1.5)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .shadow(color: .black.opacity(0.25), radius: 26, y: 12)
                        .padding(.horizontal, 24)
                    }
                    .accessibility(addTraits: .isModal)
                    .transition(.opacity)
                    .zIndex(10)
                    .onAppear {
                        isCancelFocused = true
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: confirmation != nil)
            .onChange(of: confirmation) { oldValue, newValue in
                if oldValue != nil, newValue != nil, oldValue != newValue {
                    isCancelFocused = true
                }
            }
    }
}
