import XCTest
@testable import KeyVoxCore

@MainActor
final class DictationPipelineTests: XCTestCase {
    func testPipelineProcessesAndPastesFormattedText() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "project notes one cue board two cue board", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [DictionaryEntry(phrase: "Cueboard")] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: true
        )

        XCTAssertEqual(result.rawText, "project notes one cue board two cue board")
        XCTAssertEqual(result.baseText, "Project notes:\n\n1. Cueboard\n2. Cueboard")
        XCTAssertEqual(result.finalText, "Project notes:\n\n1. Cueboard\n2. Cueboard")
        XCTAssertFalse(result.wasLikelyNoSpeech)
        XCTAssertFalse(result.textTransformationApplied)
        XCTAssertNil(result.textTransformationStyleIdentifier)
        XCTAssertEqual(result.textTransformationChunkCount, 0)
        XCTAssertEqual(result.textTransformationErrors, [])
        XCTAssertEqual(provider.receivedAudioFrames, audioFrames)
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, true)
        XCTAssertEqual(provider.receivedEnableAutoParagraphs, true)
        XCTAssertEqual(recorded, ["Project notes:\n\n1. Cueboard\n2. Cueboard"])
        XCTAssertEqual(pasted, ["Project notes:\n\n1. Cueboard\n2. Cueboard"])
    }

    func testPipelineEmitsDeterministicParagraphAndListVariants() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "project notes one cue board two cue board", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [DictionaryEntry(phrase: "Cueboard")] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { _ in },
            pasteText: { _ in }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )
        let variants = Dictionary(
            uniqueKeysWithValues: result.deterministicVariants.map {
                (DeterministicVariantKey($0), $0.text)
            }
        )

        XCTAssertEqual(result.deterministicVariants.count, 4)
        XCTAssertEqual(variants[.init(paragraphsEnabled: false, listsEnabled: false)], "Project notes one Cueboard two Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: true, listsEnabled: false)], "Project notes one Cueboard two Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: false, listsEnabled: true)], "Project notes: 1. Cueboard; 2. Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: true, listsEnabled: true)], result.baseText)
    }

    func testPipelineEmitsListEnabledDeterministicVariantsWhenListsAreOff() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "project notes one cue board two cue board", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [DictionaryEntry(phrase: "Cueboard")] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { false },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { _ in },
            pasteText: { _ in }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )
        let variants = Dictionary(
            uniqueKeysWithValues: result.deterministicVariants.map {
                (DeterministicVariantKey($0), $0.text)
            }
        )

        XCTAssertEqual(result.baseText, "Project notes one Cueboard two Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: false, listsEnabled: true)], "Project notes: 1. Cueboard; 2. Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: true, listsEnabled: true)], "Project notes:\n\n1. Cueboard\n2. Cueboard")
    }

    func testPipelineEmitsDeterministicVariantsWhenParagraphsAndListsAreOff() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "project notes one cue board two cue board", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [DictionaryEntry(phrase: "Cueboard")] },
            autoParagraphsEnabledProvider: { false },
            listFormattingEnabledProvider: { false },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { _ in },
            pasteText: { _ in }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )
        let variants = Dictionary(
            uniqueKeysWithValues: result.deterministicVariants.map {
                (DeterministicVariantKey($0), $0.text)
            }
        )

        XCTAssertEqual(result.deterministicVariants.count, 4)
        XCTAssertEqual(result.baseText, "Project notes one Cueboard two Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: false, listsEnabled: false)], "Project notes one Cueboard two Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: true, listsEnabled: false)], "Project notes one Cueboard two Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: false, listsEnabled: true)], "Project notes: 1. Cueboard; 2. Cueboard")
        XCTAssertEqual(variants[.init(paragraphsEnabled: true, listsEnabled: true)], "Project notes:\n\n1. Cueboard\n2. Cueboard")
    }

    func testPipelineAppliesBuiltInDictionaryEntryAndRefreshesProviderPrompt() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "my app is called key box", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: true
        )

        XCTAssertEqual(provider.receivedDictionaryHintPrompt, "Domain vocabulary: KeyVox, KeyVox Speak, KeyVox Vibes")
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, true)
        XCTAssertEqual(result.finalText, "My app is called KeyVox")
        XCTAssertEqual(recorded, ["My app is called KeyVox"])
        XCTAssertEqual(pasted, ["My app is called KeyVox"])
    }

    func testPipelineTransformsProcessedTextBeforeRecordingAndPasting() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "hello world", languageCode: "en")
        )
        var processedTexts: [String] = []
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) },
            processOutputText: { text in
                processedTexts.append(text)
                return DictationPipelineTextProcessingResult(
                    text: "Ahoy, world",
                    duration: 0,
                    applied: true,
                    styleIdentifier: "test-style",
                    chunkCount: 1,
                    errorDescription: nil,
                    errors: []
                )
            }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(processedTexts, ["Hello world"])
        XCTAssertEqual(result.rawText, "hello world")
        XCTAssertEqual(result.baseText, "Hello world")
        XCTAssertEqual(result.finalText, "Ahoy, world")
        XCTAssertTrue(result.textTransformationApplied)
        XCTAssertEqual(result.textTransformationStyleIdentifier, "test-style")
        XCTAssertEqual(result.textTransformationChunkCount, 1)
        XCTAssertNil(result.textTransformationErrorDescription)
        XCTAssertEqual(recorded, ["Ahoy, world"])
        XCTAssertEqual(pasted, ["Ahoy, world"])
    }

    func testCapsLockOverridesTransformedTextCasing() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "hello world", languageCode: "en")
        )
        var processedTexts: [String] = []
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            capsLockEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) },
            processOutputText: { text in
                processedTexts.append(text)
                return DictationPipelineTextProcessingResult(
                    text: "Styled mixed casing",
                    duration: 0,
                    applied: true,
                    styleIdentifier: "test-style",
                    chunkCount: 1,
                    errorDescription: nil,
                    errors: []
                )
            }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(processedTexts, ["Hello world"])
        XCTAssertEqual(result.baseText, "Hello world")
        XCTAssertEqual(result.finalText, "STYLED MIXED CASING")
        XCTAssertEqual(recorded, ["STYLED MIXED CASING"])
        XCTAssertEqual(pasted, ["STYLED MIXED CASING"])
    }

    func testPipelinePastesProcessedTextWhenTransformationFails() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "hello world", languageCode: "en")
        )
        var processedTexts: [String] = []
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) },
            processOutputText: { text in
                processedTexts.append(text)
                return DictationPipelineTextProcessingResult(
                    text: text,
                    duration: 0,
                    applied: false,
                    styleIdentifier: "test-style",
                    chunkCount: 1,
                    errorDescription: "failed",
                    errors: ["failed"]
                )
            }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(processedTexts, ["Hello world"])
        XCTAssertEqual(result.finalText, "Hello world")
        XCTAssertFalse(result.textTransformationApplied)
        XCTAssertEqual(result.textTransformationChunkCount, 1)
        XCTAssertNotNil(result.textTransformationErrorDescription)
        XCTAssertEqual(result.textTransformationErrors, ["failed"])
        XCTAssertEqual(recorded, ["Hello world"])
        XCTAssertEqual(pasted, ["Hello world"])
    }

    func testPasteDurationDoesNotIncludeOutputProcessingDelay() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "hello world", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { [self] in recorded.append($0) },
            pasteText: { [self] in pasted.append($0) },
            processOutputText: { text in
                try? await Task.sleep(nanoseconds: 150_000_000)
                return DictationPipelineTextProcessingResult(
                    text: text,
                    duration: 0.15,
                    applied: false,
                    styleIdentifier: "test-style",
                    chunkCount: 1,
                    errorDescription: nil,
                    errors: []
                )
            }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(result.finalText, "Hello world")
        XCTAssertLessThan(result.pasteDuration, 0.1)
        XCTAssertEqual(recorded, ["Hello world"])
        XCTAssertEqual(pasted, ["Hello world"])
    }

    func testPipelineKeepsProviderHintDisabledWhenAudioGateDisallowsHinting() async throws {
        let provider = StubTranscriptionProvider(
            result: .init(text: "my app is called key box", languageCode: "en")
        )
        let audioFrames = Array(repeating: Float(0.1), count: 128)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { _ in },
            pasteText: { _ in }
        )

        _ = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(provider.receivedDictionaryHintPrompt, "Domain vocabulary: KeyVox, KeyVox Speak, KeyVox Vibes")
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, false)
    }

    func testPipelineSuppressesLikelyNoSpeechResults() async throws {
        let provider = StubTranscriptionProvider(
            result: nil,
            lastResultWasLikelyNoSpeech: true
        )
        let audioFrames = Array(repeating: Float(0.0), count: 32)
        let pipeline = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { _ in XCTFail("Should not record") },
            pasteText: { _ in XCTFail("Should not paste") }
        )

        let result = await runPipeline(
            pipeline,
            audioFrames: audioFrames,
            useDictionaryHintPrompt: false
        )

        XCTAssertEqual(result.rawText, "")
        XCTAssertEqual(result.finalText, "")
        XCTAssertTrue(result.wasLikelyNoSpeech)
        XCTAssertEqual(provider.receivedAudioFrames, audioFrames)
        XCTAssertEqual(provider.receivedUseDictionaryHintPrompt, false)
        XCTAssertEqual(provider.receivedEnableAutoParagraphs, true)
    }

    func testPipelineCompletesAfterExternalPipelineReferenceIsReleased() async throws {
        let provider = DeferredTranscriptionProvider()
        let audioFrames = Array(repeating: Float(0.1), count: 64)
        var pipeline: DictationPipeline? = DictationPipeline(
            transcriptionProvider: provider,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { [] },
            autoParagraphsEnabledProvider: { false },
            listFormattingEnabledProvider: { false },
            listRenderModeProvider: { .singleLineInline },
            recordSpokenWords: { _ in },
            pasteText: { _ in }
        )
        let expectation = expectation(description: "Pipeline completion")
        var result: DictationPipelineResult?

        pipeline?.run(audioFrames: audioFrames, useDictionaryHintPrompt: false) {
            result = $0
            expectation.fulfill()
        }

        pipeline = nil
        provider.complete(with: .init(text: "hello world", languageCode: "en"))
        await fulfillment(of: [expectation], timeout: 1.0)

        XCTAssertEqual(result?.rawText, "hello world")
        XCTAssertEqual(result?.finalText, "Hello world")
        XCTAssertEqual(result?.wasLikelyNoSpeech, false)
    }

    private var recorded: [String] = []
    private var pasted: [String] = []

    override func setUp() {
        super.setUp()
        recorded = []
        pasted = []
    }

    private func runPipeline(
        _ pipeline: DictationPipeline,
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool
    ) async -> DictationPipelineResult {
        await withCheckedContinuation { continuation in
            pipeline.run(audioFrames: audioFrames, useDictionaryHintPrompt: useDictionaryHintPrompt) {
                continuation.resume(returning: $0)
            }
        }
    }

}

private struct DeterministicVariantKey: Hashable {
    let paragraphsEnabled: Bool
    let listsEnabled: Bool

    init(_ variant: DictationPipelineResult.DeterministicTextVariant) {
        self.paragraphsEnabled = variant.paragraphsEnabled
        self.listsEnabled = variant.listsEnabled
    }

    init(paragraphsEnabled: Bool, listsEnabled: Bool) {
        self.paragraphsEnabled = paragraphsEnabled
        self.listsEnabled = listsEnabled
    }
}

@MainActor
private final class StubTranscriptionProvider: DictationTranscriptionProviding, DictationTranscriptionControlling {
    let result: TranscriptionProviderResult?
    let lastResultWasLikelyNoSpeech: Bool
    private(set) var receivedAudioFrames: [Float]?
    private(set) var receivedUseDictionaryHintPrompt: Bool?
    private(set) var receivedEnableAutoParagraphs: Bool?
    private(set) var receivedDictionaryHintPrompt: String?

    init(
        result: TranscriptionProviderResult?,
        lastResultWasLikelyNoSpeech: Bool = false
    ) {
        self.result = result
        self.lastResultWasLikelyNoSpeech = lastResultWasLikelyNoSpeech
    }

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        receivedAudioFrames = audioFrames
        receivedUseDictionaryHintPrompt = useDictionaryHintPrompt
        receivedEnableAutoParagraphs = enableAutoParagraphs
        completion(result)
    }

    func cancelTranscription() {}

    func updateDictionaryHintPrompt(_ prompt: String) {
        receivedDictionaryHintPrompt = prompt
    }
}

@MainActor
private final class DeferredTranscriptionProvider: DictationTranscriptionProviding, DictationTranscriptionControlling {
    let lastResultWasLikelyNoSpeech = false
    private var completion: ((TranscriptionProviderResult?) -> Void)?

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        self.completion = completion
    }

    func complete(with result: TranscriptionProviderResult?) {
        completion?(result)
        completion = nil
    }

    func cancelTranscription() {}

    func updateDictionaryHintPrompt(_ prompt: String) {}
}
