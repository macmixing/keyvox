import Foundation

@MainActor
public protocol DictationTranscriptionProviding: AnyObject {
    /// This flag is only meaningful when the provider returns empty text for a request.
    var lastResultWasLikelyNoSpeech: Bool { get }
    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    )
}

@MainActor
public protocol DictationTranscriptionControlling: AnyObject {
    func cancelTranscription()
    func updateDictionaryHintPrompt(_ prompt: String)
}

@MainActor
public protocol DictationModelLifecycleProviding: AnyObject {
    func warmup()
    func unloadModel()
}

@MainActor
public protocol DictationModelReadinessProviding: AnyObject {
    var isModelReady: Bool { get }
}

public typealias DictationProvider =
    DictationTranscriptionProviding &
    DictationTranscriptionControlling &
    DictationModelLifecycleProviding &
    DictationModelReadinessProviding

public struct TranscriptionProviderResult: Sendable {
    public let text: String
    public let languageCode: String?
    public let paragraphsText: String?
    public let inlineText: String?

    public init(
        text: String,
        languageCode: String?,
        paragraphsText: String?,
        inlineText: String?
    ) {
        self.text = text
        self.languageCode = languageCode
        self.paragraphsText = paragraphsText
        self.inlineText = inlineText
    }
}

public struct DictationPipelineResult: Sendable {
    public struct DeterministicTextVariant: Sendable {
        public let paragraphsEnabled: Bool
        public let listsEnabled: Bool
        public let text: String

        public init(
            paragraphsEnabled: Bool,
            listsEnabled: Bool,
            text: String
        ) {
            self.paragraphsEnabled = paragraphsEnabled
            self.listsEnabled = listsEnabled
            self.text = text
        }
    }

    public let id: UUID
    public let rawText: String
    public let baseText: String
    public let uncappedFinalText: String
    public let finalText: String
    public let baseParagraphsEnabled: Bool
    public let baseListsEnabled: Bool
    public let deterministicVariants: [DeterministicTextVariant]
    public let wasLikelyNoSpeech: Bool
    public let inferenceDuration: TimeInterval
    public let textTransformationDuration: TimeInterval
    public let textTransformationApplied: Bool
    public let textTransformationStyleIdentifier: String?
    public let textTransformationChunkCount: Int
    public let textTransformationErrorDescription: String?
    public let textTransformationErrors: [String]
    public let textTransformationProcessingMode: String?
    public let pasteDuration: TimeInterval
}

public struct DictationPipelineTextProcessingResult: Equatable, Sendable {
    public let text: String
    public let duration: TimeInterval
    public let applied: Bool
    public let styleIdentifier: String?
    public let chunkCount: Int
    public let errorDescription: String?
    public let errors: [String]
    public let processingMode: String?

    public init(
        text: String,
        duration: TimeInterval,
        applied: Bool,
        styleIdentifier: String?,
        chunkCount: Int,
        errorDescription: String?,
        errors: [String],
        processingMode: String? = nil
    ) {
        self.text = text
        self.duration = duration
        self.applied = applied
        self.styleIdentifier = styleIdentifier
        self.chunkCount = chunkCount
        self.errorDescription = errorDescription
        self.errors = errors
        self.processingMode = processingMode
    }

    public static func unchanged(_ text: String) -> DictationPipelineTextProcessingResult {
        DictationPipelineTextProcessingResult(
            text: text,
            duration: 0,
            applied: false,
            styleIdentifier: nil,
            chunkCount: 0,
            errorDescription: nil,
            errors: [],
            processingMode: nil
        )
    }
}

public struct DictationPipelineTextProcessingContext: Sendable {
    public let rawText: String
    public let baseText: String
    public let baseParagraphsEnabled: Bool
    public let baseListsEnabled: Bool
    public let deterministicVariants: [DictationPipelineResult.DeterministicTextVariant]

    public init(
        rawText: String,
        baseText: String,
        baseParagraphsEnabled: Bool,
        baseListsEnabled: Bool,
        deterministicVariants: [DictationPipelineResult.DeterministicTextVariant]
    ) {
        self.rawText = rawText
        self.baseText = baseText
        self.baseParagraphsEnabled = baseParagraphsEnabled
        self.baseListsEnabled = baseListsEnabled
        self.deterministicVariants = deterministicVariants
    }
}

@MainActor
public final class DictationPipeline {
    private let transcriptionProvider: DictationTranscriptionProviding
    private let transcriptionController: (any DictationTranscriptionControlling)?
    private let postProcessor: TranscriptionPostProcessor
    private let allCapsOverrideNormalizer = AllCapsOverrideNormalizer()
    private let dictionaryEntriesProvider: () -> [DictionaryEntry]
    private let autoParagraphsEnabledProvider: () -> Bool
    private let listFormattingEnabledProvider: () -> Bool
    private let capsLockEnabledProvider: () -> Bool
    private let listRenderModeProvider: () -> ListRenderMode
    private let recordSpokenWords: (String) -> Void
    private let pasteText: (String) -> Void
    private let processOutputText: (DictationPipelineTextProcessingContext) async -> DictationPipelineTextProcessingResult

    public init(
        transcriptionProvider: DictationTranscriptionProviding,
        postProcessor: TranscriptionPostProcessor,
        dictionaryEntriesProvider: @escaping () -> [DictionaryEntry],
        autoParagraphsEnabledProvider: @escaping () -> Bool,
        listFormattingEnabledProvider: @escaping () -> Bool,
        capsLockEnabledProvider: @escaping () -> Bool = { false },
        listRenderModeProvider: @escaping () -> ListRenderMode,
        recordSpokenWords: @escaping (String) -> Void,
        pasteText: @escaping (String) -> Void,
        processOutputText: @escaping (String) async -> DictationPipelineTextProcessingResult = {
            .unchanged($0)
        },
        processOutputTextWithContext: ((DictationPipelineTextProcessingContext) async -> DictationPipelineTextProcessingResult)? = nil
    ) {
        self.transcriptionProvider = transcriptionProvider
        self.transcriptionController = transcriptionProvider as? any DictationTranscriptionControlling
        self.postProcessor = postProcessor
        self.dictionaryEntriesProvider = dictionaryEntriesProvider
        self.autoParagraphsEnabledProvider = autoParagraphsEnabledProvider
        self.listFormattingEnabledProvider = listFormattingEnabledProvider
        self.capsLockEnabledProvider = capsLockEnabledProvider
        self.listRenderModeProvider = listRenderModeProvider
        self.recordSpokenWords = recordSpokenWords
        self.pasteText = pasteText
        self.processOutputText = processOutputTextWithContext ?? { context in
            await processOutputText(context.baseText)
        }
    }

    public func run(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        completion: @escaping (DictationPipelineResult) -> Void
    ) {
        let utteranceID = UUID()
        let inferenceStart = Date()
        let autoParagraphsEnabled = autoParagraphsEnabledProvider()
        let listFormattingEnabled = listFormattingEnabledProvider()
        let userDictionaryEntries = dictionaryEntriesProvider()
        let shouldUseDictionaryHintPrompt = useDictionaryHintPrompt
            && DictionaryBuiltInEntries.hasEffectiveEntries(merging: userDictionaryEntries)
        transcriptionController?.updateDictionaryHintPrompt(
            DictionaryHintPromptBuilder.prompt(for: userDictionaryEntries)
        )
        transcriptionProvider.transcribe(
            audioFrames: audioFrames,
            useDictionaryHintPrompt: shouldUseDictionaryHintPrompt,
            enableAutoParagraphs: autoParagraphsEnabled
        ) { [self] result in
            let inferenceDuration = Date().timeIntervalSince(inferenceStart)
            let rawText = result?.text ?? ""
            let paragraphRawText = result?.paragraphsText ?? rawText
            let inlineRawText = result?.inlineText ?? rawText
            let languageCode = result?.languageCode
            let wasLikelyNoSpeech = rawText.isEmpty && self.transcriptionProvider.lastResultWasLikelyNoSpeech
            #if DEBUG
            self.logPipelineStage("rawText", rawText)
            #endif

            guard !wasLikelyNoSpeech else {
                Task { @MainActor in
                    completion(
                        DictationPipelineResult(
                            id: utteranceID,
                            rawText: rawText,
                            baseText: "",
                            uncappedFinalText: "",
                            finalText: "",
                            baseParagraphsEnabled: autoParagraphsEnabled,
                            baseListsEnabled: listFormattingEnabled,
                            deterministicVariants: [],
                            wasLikelyNoSpeech: true,
                            inferenceDuration: inferenceDuration,
                            textTransformationDuration: 0,
                            textTransformationApplied: false,
                            textTransformationStyleIdentifier: nil,
                            textTransformationChunkCount: 0,
                            textTransformationErrorDescription: nil,
                            textTransformationErrors: [],
                            textTransformationProcessingMode: nil,
                            pasteDuration: 0
                        )
                    )
                }
                return
            }

            let dictionaryEntries = DictionaryBuiltInEntries.effectiveEntries(
                merging: userDictionaryEntries
            )
            let renderMode = self.listRenderModeProvider()
            Task { @MainActor [self] in
                let finalText = await self.postProcessor.processAsync(
                    rawText,
                    dictionaryEntries: dictionaryEntries,
                    renderMode: renderMode,
                    listFormattingEnabled: listFormattingEnabled,
                    forceAllCaps: false,
                    languageCode: languageCode
                )
                #if DEBUG
                self.logPipelineStage("finalText", finalText)
                #endif

                if DictationPromptEchoGuard.shouldTreatAsNoSpeech(
                    processedText: finalText,
                    dictionaryEntries: dictionaryEntries,
                    usedDictionaryHintPrompt: shouldUseDictionaryHintPrompt
                ) {
                    #if DEBUG
                    print("DictationPipeline: Suppressed likely dictionary prompt echo output.")
                    #endif
                    completion(
                        DictationPipelineResult(
                            id: utteranceID,
                            rawText: rawText,
                            baseText: finalText,
                            uncappedFinalText: "",
                            finalText: "",
                            baseParagraphsEnabled: autoParagraphsEnabled,
                            baseListsEnabled: listFormattingEnabled,
                            deterministicVariants: [],
                            wasLikelyNoSpeech: true,
                            inferenceDuration: inferenceDuration,
                            textTransformationDuration: 0,
                            textTransformationApplied: false,
                            textTransformationStyleIdentifier: nil,
                            textTransformationChunkCount: 0,
                            textTransformationErrorDescription: nil,
                            textTransformationErrors: [],
                            textTransformationProcessingMode: nil,
                            pasteDuration: 0
                        )
                    )
                    return
                }

                let deterministicVariants = await self.deterministicVariants(
                    paragraphRawText: paragraphRawText,
                    inlineRawText: inlineRawText,
                    dictionaryEntries: dictionaryEntries,
                    renderMode: renderMode,
                    languageCode: languageCode
                )
                let processingContext = DictationPipelineTextProcessingContext(
                    rawText: rawText,
                    baseText: finalText,
                    baseParagraphsEnabled: autoParagraphsEnabled,
                    baseListsEnabled: listFormattingEnabled,
                    deterministicVariants: deterministicVariants
                )
                let output = await self.processOutputText(processingContext)
                let outputText = self.allCapsOverrideNormalizer.normalize(
                    in: output.text,
                    isEnabled: self.capsLockEnabledProvider()
                )
                let pasteStart = Date()

                if !outputText.isEmpty {
                    self.recordSpokenWords(outputText)
                    self.pasteText(outputText)
                }

                let pasteDuration = outputText.isEmpty ? 0 : Date().timeIntervalSince(pasteStart)

                completion(
                    DictationPipelineResult(
                        id: utteranceID,
                        rawText: rawText,
                        baseText: finalText,
                        uncappedFinalText: output.text,
                        finalText: outputText,
                        baseParagraphsEnabled: autoParagraphsEnabled,
                        baseListsEnabled: listFormattingEnabled,
                        deterministicVariants: deterministicVariants,
                        wasLikelyNoSpeech: false,
                        inferenceDuration: inferenceDuration,
                        textTransformationDuration: output.duration,
                        textTransformationApplied: output.applied,
                        textTransformationStyleIdentifier: output.styleIdentifier,
                        textTransformationChunkCount: output.chunkCount,
                        textTransformationErrorDescription: output.errorDescription,
                        textTransformationErrors: output.errors,
                        textTransformationProcessingMode: output.processingMode,
                        pasteDuration: pasteDuration
                    )
                )
            }
        }
    }

    private func deterministicVariants(
        paragraphRawText: String,
        inlineRawText: String,
        dictionaryEntries: [DictionaryEntry],
        renderMode: ListRenderMode,
        languageCode: String?
    ) async -> [DictationPipelineResult.DeterministicTextVariant] {
        #if DEBUG
        return await TranscriptionPostProcessingDebugLogging.$isEnabled.withValue(false) {
            await makeDeterministicVariants(
                paragraphRawText: paragraphRawText,
                inlineRawText: inlineRawText,
                dictionaryEntries: dictionaryEntries,
                renderMode: renderMode,
                languageCode: languageCode
            )
        }
        #else
        return await makeDeterministicVariants(
            paragraphRawText: paragraphRawText,
            inlineRawText: inlineRawText,
            dictionaryEntries: dictionaryEntries,
            renderMode: renderMode,
            languageCode: languageCode
        )
        #endif
    }

    private func makeDeterministicVariants(
        paragraphRawText: String,
        inlineRawText: String,
        dictionaryEntries: [DictionaryEntry],
        renderMode: ListRenderMode,
        languageCode: String?
    ) async -> [DictationPipelineResult.DeterministicTextVariant] {
        let noParagraphsNoLists = await postProcessor.processAsync(
            inlineRawText,
            dictionaryEntries: dictionaryEntries,
            renderMode: .singleLineInline,
            listFormattingEnabled: false,
            forceAllCaps: false,
            languageCode: languageCode
        )
        let paragraphsNoLists = await postProcessor.processAsync(
            paragraphRawText,
            dictionaryEntries: dictionaryEntries,
            renderMode: renderMode,
            listFormattingEnabled: false,
            forceAllCaps: false,
            languageCode: languageCode
        )
        let noParagraphsWithLists = await postProcessor.processAsync(
            inlineRawText,
            dictionaryEntries: dictionaryEntries,
            renderMode: renderMode,
            listFormattingEnabled: true,
            forceAllCaps: false,
            languageCode: languageCode
        )
        let paragraphsWithLists = await postProcessor.processAsync(
            paragraphRawText,
            dictionaryEntries: dictionaryEntries,
            renderMode: renderMode,
            listFormattingEnabled: true,
            forceAllCaps: false,
            languageCode: languageCode
        )

        return [
            DictationPipelineResult.DeterministicTextVariant(
                paragraphsEnabled: false,
                listsEnabled: false,
                text: noParagraphsNoLists
            ),
            DictationPipelineResult.DeterministicTextVariant(
                paragraphsEnabled: true,
                listsEnabled: false,
                text: paragraphsNoLists
            ),
            DictationPipelineResult.DeterministicTextVariant(
                paragraphsEnabled: false,
                listsEnabled: true,
                text: noParagraphsWithLists
            ),
            DictationPipelineResult.DeterministicTextVariant(
                paragraphsEnabled: true,
                listsEnabled: true,
                text: paragraphsWithLists
            ),
        ]
    }

    #if DEBUG
    private func logPipelineStage(_ stage: String, _ value: String) {
        guard TranscriptionPostProcessingDebugLogging.isEnabled else { return }
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
