import Foundation
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
            return String(localized: "Delete Dictation Model?", comment: "Title of the confirmation shown before deleting a downloaded dictation model.")
        case .keyVoxVibesAI:
            return String(localized: "Delete KeyVox Vibes AI?", comment: "Title of the confirmation shown before deleting the Vibes AI model. KeyVox Vibes AI is a brand name and stays in English.")
        case .sharedTTSModel:
            return String(localized: "Delete Speak Engine?", comment: "Title of the confirmation shown before deleting the KeyVox Speak text-to-speech engine. Speak is a brand name and stays in English.")
        case .ttsVoice:
            return String(localized: "Delete Voice?", comment: "Title of the confirmation shown before deleting a downloaded KeyVox Speak voice.")
        case .learnedWords:
            return String(localized: "Reset Learned Words?", comment: "Title of the confirmation shown before clearing the words the KeyVox keyboard has learned.")
        }
    }

    var message: String {
        switch self {
        case .dictationModel(let modelID):
            return String(localized: "Delete the \(modelID.provider.displayName) model from this device?", comment: "Message in the confirmation shown before deleting a dictation model. The placeholder is the model name, a brand name that stays in English.")
        case .keyVoxVibesAI:
            return String(localized: "Delete KeyVox Vibes AI from this device?", comment: "Message in the confirmation shown before deleting the Vibes AI model. KeyVox Vibes AI is a brand name and stays in English.")
        case .sharedTTSModel:
            return String(localized: "Delete the KeyVox Speak engine and all downloaded voices from this device?", comment: "Message in the confirmation shown before deleting the text-to-speech engine. KeyVox Speak is a brand name and stays in English.")
        case .ttsVoice(let voice):
            return String(localized: "Delete the \(voice.displayName) voice from this device?", comment: "Message in the confirmation shown before deleting a KeyVox Speak voice. The placeholder is the voice name, which stays in English.")
        case .learnedWords:
            return String(localized: "KeyVox will forget the words it learned from your typing and the corrections you undid. Your KeyVox Dictionary isn't affected.", comment: "Message in the confirmation shown before resetting the keyboard's learned words. KeyVox is a brand name and stays in English; Dictionary refers to the app's Dictionary tab.")
        }
    }

    /// The title of the red button that goes ahead.
    var confirmTitle: String {
        switch self {
        case .dictationModel, .keyVoxVibesAI, .sharedTTSModel, .ttsVoice:
            return String(localized: "Delete", comment: "Destructive button in a confirmation that deletes a downloaded model or voice.")
        case .learnedWords:
            return String(localized: "Reset", comment: "Destructive button in the confirmation that clears the keyboard's learned words.")
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

                            VStack(spacing: 12) {
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

                                AppActionButton(
                                    title: String(localized: "Cancel", comment: "Button that closes the delete confirmation without deleting anything."),
                                    style: .secondary,
                                    fillsWidth: true,
                                    size: .regular,
                                    fontSize: 16,
                                    action: {
                                        self.confirmation = nil
                                    }
                                )
                                .accessibilityFocused($isConfirmFocused)
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
