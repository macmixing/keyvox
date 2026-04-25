import SwiftUI

enum PendingDownloadConfirmation: Identifiable, Equatable {
    case dictationModel(DictationModelID)
    case sharedTTSModel
    case ttsVoice(AppSettingsStore.TTSVoice)
    case ttsVoiceWithSharedModel(AppSettingsStore.TTSVoice)

    var id: String {
        switch self {
        case .dictationModel(let modelID):
            return "dictation-\(modelID.rawValue)"
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
                return "Download Whisper Base?"
            case .parakeetTdtV3:
                return "Download Parakeet v3?"
            }
        case .sharedTTSModel:
            return "Download Speak Engine?"
        case .ttsVoice(let voice):
            return "Download \(voice.displayName)'s Voice?"
        case .ttsVoiceWithSharedModel:
            return "Download KeyVox Speak?"
        }
    }

    var message: String {
        switch self {
        case .dictationModel(let modelID):
            switch modelID {
            case .whisperBase:
                return "Download the Whisper Base dictation model (~190 MB) before using local dictation on this device?"
            case .parakeetTdtV3:
                return "Download the Parakeet v3 dictation model (~480 MB) for faster on-device dictation on this device?"
            }
        case .sharedTTSModel:
            return "Download the KeyVox Speak engine (~642 MB) to speak copied text on this device?"
        case .ttsVoice(let voice):
            return "Download \(voice.displayName)'s voice (~19 MB) to speak copied text on this device?"
        case .ttsVoiceWithSharedModel(let voice):
            return "Download the KeyVox Speak engine and \(voice.displayName)'s voice (~661 MB total) to speak copied text on this device?"
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

                            HStack(spacing: 12) {
                                AppActionButton(
                                    title: "Cancel",
                                    style: .secondary,
                                    fillsWidth: true,
                                    size: .regular,
                                    fontSize: 16,
                                    action: {
                                        self.confirmation = nil
                                    }
                                )
                                .accessibilityFocused($isCancelFocused)

                                AppActionButton(
                                    title: "Download",
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
