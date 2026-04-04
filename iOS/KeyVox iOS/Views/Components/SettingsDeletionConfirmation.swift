import SwiftUI

enum SettingsPendingDeletionConfirmation: Identifiable {
    case dictationModel(DictationModelID)
    case sharedTTSModel
    case ttsVoice(AppSettingsStore.TTSVoice)

    var id: String {
        switch self {
        case .dictationModel(let modelID):
            return "dictation-\(modelID.rawValue)"
        case .sharedTTSModel:
            return "tts-shared"
        case .ttsVoice(let voice):
            return "tts-voice-\(voice.rawValue)"
        }
    }

    var title: String {
        switch self {
        case .dictationModel:
            return "Delete Text Model?"
        case .sharedTTSModel:
            return "Delete Voice Runtime?"
        case .ttsVoice:
            return "Delete Voice?"
        }
    }

    var message: String {
        switch self {
        case .dictationModel(let modelID):
            return "Delete the \(modelID.provider.displayName) model from this device?"
        case .sharedTTSModel:
            return "Delete PocketTTS CoreML and all downloaded voices from this device?"
        case .ttsVoice(let voice):
            return "Delete the \(voice.displayName) voice from this device?"
        }
    }
}

extension View {
    func settingsDeletionConfirmation(
        _ confirmation: Binding<SettingsPendingDeletionConfirmation?>,
        onConfirm: @escaping (SettingsPendingDeletionConfirmation) -> Void
    ) -> some View {
        modifier(
            SettingsDeletionConfirmationModifier(
                confirmation: confirmation,
                onConfirm: onConfirm
            )
        )
    }
}

private struct SettingsDeletionConfirmationModifier: ViewModifier {
    @Binding var confirmation: SettingsPendingDeletionConfirmation?
    let onConfirm: (SettingsPendingDeletionConfirmation) -> Void

    func body(content: Content) -> some View {
        content
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

                                AppActionButton(
                                    title: "Delete",
                                    style: .destructive,
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
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .animation(.easeInOut(duration: 0.18), value: confirmation != nil)
    }
}
