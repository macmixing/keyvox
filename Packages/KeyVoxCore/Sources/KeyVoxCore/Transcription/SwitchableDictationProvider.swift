import Foundation

@MainActor
public final class SwitchableDictationProvider: DictationProvider {
    private var activeProvider: any DictationProvider

    public init(initialProvider: any DictationProvider) {
        self.activeProvider = initialProvider
    }

    public var isModelReady: Bool {
        activeProvider.isModelReady
    }

    public var lastResultWasLikelyNoSpeech: Bool {
        activeProvider.lastResultWasLikelyNoSpeech
    }

    public func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        activeProvider.transcribe(
            audioFrames: audioFrames,
            useDictionaryHintPrompt: useDictionaryHintPrompt,
            enableAutoParagraphs: enableAutoParagraphs,
            completion: completion
        )
    }

    public func cancelTranscription() {
        activeProvider.cancelTranscription()
    }

    public func updateDictionaryHintPrompt(_ prompt: String) {
        activeProvider.updateDictionaryHintPrompt(prompt)
    }

    public func warmup() {
        activeProvider.warmup()
    }

    public func unloadModel() {
        activeProvider.unloadModel()
    }

    public func replaceActiveProvider(
        with provider: any DictationProvider,
        cancelCurrentWork: Bool = true,
        unloadPreviousModel: Bool = true,
        warmNewProviderIfReady: Bool = true
    ) {
        let previousProvider = activeProvider

        if cancelCurrentWork {
            previousProvider.cancelTranscription()
        }

        if unloadPreviousModel {
            previousProvider.unloadModel()
        }

        activeProvider = provider

        if warmNewProviderIfReady && provider.isModelReady {
            provider.warmup()
        }
    }
}
