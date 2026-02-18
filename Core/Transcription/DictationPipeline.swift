import Foundation

protocol DictationTranscriptionProviding: AnyObject {
    var lastResultWasLikelyNoSpeech: Bool { get }
    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (String?) -> Void
    )
}

extension WhisperService: DictationTranscriptionProviding {}

struct DictationPipelineResult {
    let rawText: String
    let finalText: String
    let wasLikelyNoSpeech: Bool
    let inferenceDuration: TimeInterval
    let pasteDuration: TimeInterval
}

@MainActor
final class DictationPipeline {
    private let transcriptionProvider: DictationTranscriptionProviding
    private let postProcessor: TranscriptionPostProcessor
    private let dictionaryEntriesProvider: () -> [DictionaryEntry]
    private let autoParagraphsEnabledProvider: () -> Bool
    private let listRenderModeProvider: () -> ListRenderMode
    private let recordSpokenWords: (String) -> Void
    private let pasteText: (String) -> Void

    init(
        transcriptionProvider: DictationTranscriptionProviding,
        postProcessor: TranscriptionPostProcessor,
        dictionaryEntriesProvider: @escaping () -> [DictionaryEntry],
        autoParagraphsEnabledProvider: @escaping () -> Bool,
        listRenderModeProvider: @escaping () -> ListRenderMode,
        recordSpokenWords: @escaping (String) -> Void,
        pasteText: @escaping (String) -> Void
    ) {
        self.transcriptionProvider = transcriptionProvider
        self.postProcessor = postProcessor
        self.dictionaryEntriesProvider = dictionaryEntriesProvider
        self.autoParagraphsEnabledProvider = autoParagraphsEnabledProvider
        self.listRenderModeProvider = listRenderModeProvider
        self.recordSpokenWords = recordSpokenWords
        self.pasteText = pasteText
    }

    func run(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        completion: @escaping (DictationPipelineResult) -> Void
    ) {
        let inferenceStart = Date()
        let autoParagraphsEnabled = autoParagraphsEnabledProvider()
        transcriptionProvider.transcribe(
            audioFrames: audioFrames,
            useDictionaryHintPrompt: useDictionaryHintPrompt,
            enableAutoParagraphs: autoParagraphsEnabled
        ) { [weak self] result in
            guard let self else { return }

            let inferenceDuration = Date().timeIntervalSince(inferenceStart)
            let rawText = result ?? ""
            let wasLikelyNoSpeech = rawText.isEmpty && self.transcriptionProvider.lastResultWasLikelyNoSpeech

            guard !wasLikelyNoSpeech else {
                completion(
                    DictationPipelineResult(
                        rawText: rawText,
                        finalText: "",
                        wasLikelyNoSpeech: true,
                        inferenceDuration: inferenceDuration,
                        pasteDuration: 0
                    )
                )
                return
            }

            let pasteStart = Date()
            let dictionaryEntries = self.dictionaryEntriesProvider()
            let finalText = self.postProcessor.process(
                rawText,
                dictionaryEntries: dictionaryEntries,
                renderMode: self.listRenderModeProvider()
            )

            if DictationPromptEchoGuard.shouldTreatAsNoSpeech(
                processedText: finalText,
                dictionaryEntries: dictionaryEntries,
                usedDictionaryHintPrompt: useDictionaryHintPrompt
            ) {
                #if DEBUG
                print("DictationPipeline: Suppressed likely dictionary prompt echo output.")
                #endif
                completion(
                    DictationPipelineResult(
                        rawText: rawText,
                        finalText: "",
                        wasLikelyNoSpeech: true,
                        inferenceDuration: inferenceDuration,
                        pasteDuration: Date().timeIntervalSince(pasteStart)
                    )
                )
                return
            }

            if !finalText.isEmpty {
                self.recordSpokenWords(finalText)
                self.pasteText(finalText)
            }

            let pasteDuration = Date().timeIntervalSince(pasteStart)

            completion(
                DictationPipelineResult(
                    rawText: rawText,
                    finalText: finalText,
                    wasLikelyNoSpeech: false,
                    inferenceDuration: inferenceDuration,
                    pasteDuration: pasteDuration
                )
            )
        }
    }
}
