import Foundation

enum ParakeetUpdatePromptContent {
    static func offer(onDownload: @escaping () -> Void, onLater: @escaping () -> Void) -> UpdatePrompt {
        UpdatePrompt(
            title: "Parakeet Update Available",
            message: "A newer Parakeet model is available for on-device dictation. Download the updated Parakeet model now (\(DictationModelID.parakeetTdtV3.approximateDownloadSizeText)), or do it later from Settings.",
            version: nil,
            build: nil,
            dismissButtonTitle: "Later",
            primaryButtonTitle: "Download",
            onPrimaryAction: onDownload,
            onDismiss: onLater,
            dismissesOnPrimaryAction: false
        )
    }

    static func progress(_ state: DictationModelInstallState) -> UpdatePrompt {
        UpdatePrompt(
            title: "Updating Parakeet",
            message: "You can keep dictating with your current Parakeet model while the update downloads.",
            version: nil,
            build: nil,
            dismissButtonTitle: "Later",
            primaryButtonTitle: nil,
            onPrimaryAction: nil,
            onDismiss: {},
            progress: UpdatePromptProgress(value: state.progress, statusText: state.phase.statusText)
        )
    }

    static func done() -> UpdatePrompt {
        UpdatePrompt(
            title: "Parakeet Updated",
            message: "The updated Parakeet model is installed and ready for dictation.",
            version: nil,
            build: nil,
            dismissButtonTitle: "Okay",
            primaryButtonTitle: nil,
            onPrimaryAction: nil,
            onDismiss: {}
        )
    }

    static func failed(
        errorMessage: String,
        onDownload: @escaping () -> Void,
        onLater: @escaping () -> Void
    ) -> UpdatePrompt {
        UpdatePrompt(
            title: "Parakeet Update Failed",
            message: "\(errorMessage) Your current Parakeet model is still installed.",
            version: nil,
            build: nil,
            dismissButtonTitle: "Later",
            primaryButtonTitle: "Download",
            onPrimaryAction: onDownload,
            onDismiss: onLater,
            dismissesOnPrimaryAction: false
        )
    }
}
