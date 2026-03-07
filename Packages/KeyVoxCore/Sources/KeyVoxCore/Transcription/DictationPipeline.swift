import Foundation

public protocol DictationTranscriptionProviding: AnyObject {
    var lastResultWasLikelyNoSpeech: Bool { get }
    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    )
}

public struct TranscriptionProviderResult: Sendable {
    public let text: String
    public let languageCode: String?

    public init(text: String, languageCode: String?) {
        self.text = text
        self.languageCode = languageCode
    }
}

extension WhisperService: DictationTranscriptionProviding {}

public struct DictationPipelineResult {
    public let rawText: String
    public let finalText: String
    public let wasLikelyNoSpeech: Bool
    public let inferenceDuration: TimeInterval
    public let pasteDuration: TimeInterval
}

@MainActor
public final class DictationPipeline {
    private let transcriptionProvider: DictationTranscriptionProviding
    private let postProcessor: TranscriptionPostProcessor
    private let dictionaryEntriesProvider: () -> [DictionaryEntry]
    private let autoParagraphsEnabledProvider: () -> Bool
    private let listFormattingEnabledProvider: () -> Bool
    private let capsLockEnabledProvider: () -> Bool
    private let listRenderModeProvider: () -> ListRenderMode
    private let recordSpokenWords: (String) -> Void
    private let pasteText: (String) -> Void

    public init(
        transcriptionProvider: DictationTranscriptionProviding,
        postProcessor: TranscriptionPostProcessor,
        dictionaryEntriesProvider: @escaping () -> [DictionaryEntry],
        autoParagraphsEnabledProvider: @escaping () -> Bool,
        listFormattingEnabledProvider: @escaping () -> Bool,
        capsLockEnabledProvider: @escaping () -> Bool = { false },
        listRenderModeProvider: @escaping () -> ListRenderMode,
        recordSpokenWords: @escaping (String) -> Void,
        pasteText: @escaping (String) -> Void
    ) {
        self.transcriptionProvider = transcriptionProvider
        self.postProcessor = postProcessor
        self.dictionaryEntriesProvider = dictionaryEntriesProvider
        self.autoParagraphsEnabledProvider = autoParagraphsEnabledProvider
        self.listFormattingEnabledProvider = listFormattingEnabledProvider
        self.capsLockEnabledProvider = capsLockEnabledProvider
        self.listRenderModeProvider = listRenderModeProvider
        self.recordSpokenWords = recordSpokenWords
        self.pasteText = pasteText
    }

    public func run(
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
            let rawText = result?.text ?? ""
            let languageCode = result?.languageCode
            let wasLikelyNoSpeech = rawText.isEmpty && self.transcriptionProvider.lastResultWasLikelyNoSpeech
            #if DEBUG
            self.logPipelineStage("rawText", rawText)
            #endif

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
                renderMode: self.listRenderModeProvider(),
                listFormattingEnabled: self.listFormattingEnabledProvider(),
                forceAllCaps: self.capsLockEnabledProvider(),
                languageCode: languageCode
            )
            #if DEBUG
            self.logPipelineStage("finalText", finalText)
            #endif

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

    #if DEBUG
    private func logPipelineStage(_ stage: String, _ value: String) {
        let summary = debugTextSummary(value)
        if rawDebugTextLoggingEnabled {
            print("[KVXPipeline] \(stage) \(summary) text=\(escapedDebugText(value))")
        } else {
            print("[KVXPipeline] \(stage) \(summary)")
        }
    }

    private var rawDebugTextLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"
    }

    private func debugTextSummary(_ text: String) -> String {
        let chars = text.count
        let words = text.split(whereSeparator: \.isWhitespace).count
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let firstToken: String
        if rawDebugTextLoggingEnabled {
            firstToken = text.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        } else {
            firstToken = "<redacted>"
        }
        return "chars=\(chars) words=\(words) lines=\(lines) firstToken=\(firstToken)"
    }

    private func escapedDebugText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\n")
    }
    #endif
}
