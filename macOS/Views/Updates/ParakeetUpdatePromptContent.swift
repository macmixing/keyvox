import Foundation

enum ParakeetUpdatePromptContent {
    static func offer(onDownload: @escaping () -> Void, onLater: @escaping () -> Void) -> UpdatePrompt {
        UpdatePrompt(
            title: String(localized: "Parakeet Update Available", comment: "Title of the prompt offering a Parakeet dictation model update. Parakeet is a brand name and stays in English."),
            message: String(localized: "A newer Parakeet model is available for on-device dictation. Download the updated Parakeet model now (\(DictationModelID.parakeetTdtV3.approximateDownloadSizeText)), or do it later from Settings.", comment: "Message of the prompt offering a Parakeet dictation model update. %@ is the approximate download size. Settings is the KeyVox settings window. Parakeet is a brand name and stays in English."),
            version: nil,
            build: nil,
            dismissButtonTitle: String(localized: "Later", comment: "Button in the Parakeet model update prompt that closes it for now."),
            primaryButtonTitle: String(localized: "Download", comment: "Button in the Parakeet model update prompt that downloads the updated model."),
            onPrimaryAction: onDownload,
            onDismiss: onLater,
            dismissesOnPrimaryAction: false,
            holdsPanelUntilDismissed: true
        )
    }

    static func progress(_ state: DictationModelInstallState) -> UpdatePrompt {
        UpdatePrompt(
            title: String(localized: "Updating Parakeet", comment: "Title of the prompt shown while the Parakeet dictation model update downloads. Parakeet is a brand name and stays in English."),
            message: String(localized: "KeyVox will let you know as soon as the updated Parakeet model is ready.", comment: "Message of the prompt shown while the Parakeet dictation model update downloads. KeyVox and Parakeet are brand names and stay in English."),
            version: nil,
            build: nil,
            dismissButtonTitle: String(localized: "Later", comment: "Button in the Parakeet model update prompt that closes it for now."),
            primaryButtonTitle: nil,
            onPrimaryAction: nil,
            onDismiss: {},
            progress: UpdatePromptProgress(value: state.progress, statusText: state.phase.statusText),
            holdsPanelUntilDismissed: true
        )
    }

    static func done() -> UpdatePrompt {
        UpdatePrompt(
            title: String(localized: "Parakeet Updated", comment: "Title of the prompt shown when the Parakeet dictation model update is installed. Parakeet is a brand name and stays in English."),
            message: String(localized: "The updated Parakeet model is installed and ready for dictation.", comment: "Message of the prompt shown when the Parakeet dictation model update is installed. Parakeet is a brand name and stays in English."),
            version: nil,
            build: nil,
            dismissButtonTitle: String(localized: "Okay", comment: "Button that closes the Parakeet model updated prompt."),
            primaryButtonTitle: nil,
            onPrimaryAction: nil,
            onDismiss: {},
            holdsPanelUntilDismissed: true
        )
    }

    static func blockedByActiveDownload(
        onDownload: @escaping () -> Void,
        onLater: @escaping () -> Void
    ) -> UpdatePrompt {
        failed(
            errorMessage: String(localized: "Another model is downloading. Try again when it finishes.", comment: "Error in the Parakeet model update prompt when another dictation model is already downloading."),
            onDownload: onDownload,
            onLater: onLater
        )
    }

    static func failed(
        errorMessage: String,
        onDownload: @escaping () -> Void,
        onLater: @escaping () -> Void
    ) -> UpdatePrompt {
        UpdatePrompt(
            title: String(localized: "Parakeet Update Failed", comment: "Title of the prompt shown when the Parakeet dictation model update fails. Parakeet is a brand name and stays in English."),
            message: String(localized: "\(errorMessage) Your current Parakeet model is still installed.", comment: "Message of the prompt shown when the Parakeet dictation model update fails. %@ is the error message, which is a full sentence. Parakeet is a brand name and stays in English."),
            version: nil,
            build: nil,
            dismissButtonTitle: String(localized: "Later", comment: "Button in the Parakeet model update prompt that closes it for now."),
            primaryButtonTitle: String(localized: "Download", comment: "Button in the Parakeet model update prompt that downloads the updated model."),
            onPrimaryAction: onDownload,
            onDismiss: onLater,
            dismissesOnPrimaryAction: false,
            holdsPanelUntilDismissed: true
        )
    }
}
