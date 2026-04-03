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
        alert(item: confirmation) { pendingConfirmation in
            Alert(
                title: Text(pendingConfirmation.title),
                message: Text(pendingConfirmation.message),
                primaryButton: .destructive(Text("Delete")) {
                    onConfirm(pendingConfirmation)
                },
                secondaryButton: .cancel()
            )
        }
    }
}
