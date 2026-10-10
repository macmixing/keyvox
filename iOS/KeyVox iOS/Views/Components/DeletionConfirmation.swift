import SwiftUI

enum SettingsPendingDeletionConfirmation: Identifiable, Equatable {
    case dictationModel(DictationModelID)
    case keyVoxVibesAI
    case sharedTTSModel
    case ttsVoice(AppSettingsStore.TTSVoice)
    /// What the KeyVox keyboard learned from the user's typing.
    case learnedWords

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
        case .learnedWords:
            return "learned-words"
        }
    }

    var title: String {
        switch self {
        case .dictationModel:
            return "Delete Dictation Model?"
        case .keyVoxVibesAI:
            return "Delete KeyVox Vibes AI?"
        case .sharedTTSModel:
            return "Delete Speak Engine?"
        case .ttsVoice:
            return "Delete Voice?"
        case .learnedWords:
            return "Reset Learned Words?"
        }
    }

    var message: String {
        switch self {
        case .dictationModel(let modelID):
            return "Delete the \(modelID.provider.displayName) model from this device?"
        case .keyVoxVibesAI:
            return "Delete KeyVox Vibes AI from this device?"
        case .sharedTTSModel:
            return "Delete the KeyVox Speak engine and all downloaded voices from this device?"
        case .ttsVoice(let voice):
            return "Delete the \(voice.displayName) voice from this device?"
        case .learnedWords:
            return "KeyVox will forget the words it learned from your typing and the corrections you undid. Your KeyVox Dictionary isn't affected."
        }
    }

    /// The title of the red button that goes ahead.
    var confirmTitle: String {
        switch self {
        case .dictationModel, .keyVoxVibesAI, .sharedTTSModel, .ttsVoice:
            return "Delete"
        case .learnedWords:
            return "Reset"
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
    @AccessibilityFocusState private var isConfirmFocused: Bool

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
                                .accessibilityFocused($isConfirmFocused)

                                AppActionButton(
                                    title: confirmation.confirmTitle,
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
                    .accessibility(addTraits: .isModal)
                    .transition(.opacity)
                    .zIndex(10)
                    .onAppear {
                        isConfirmFocused = true
                    }
                }
            }
            .animation(.easeInOut(duration: 0.18), value: confirmation != nil)
            .onChange(of: confirmation) { _, newValue in
                if newValue != nil {
                    isConfirmFocused = true
                }
            }
    }
}
