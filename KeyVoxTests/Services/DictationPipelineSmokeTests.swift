import AppKit
import XCTest
@testable import KeyVox

@MainActor
final class DictationPipelineSmokeTests: XCTestCase {
    private static var retainedServices: [PasteService] = []

    func testDictionaryHintPromptGateSkipsVeryShortUtterances() {
        XCTAssertFalse(
            TranscriptionManager.shouldUseDictionaryHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.28,
                maxActiveSignalRunDuration: 0.24
            )
        )

        XCTAssertFalse(
            TranscriptionManager.shouldUseDictionaryHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.62,
                maxActiveSignalRunDuration: 0.20
            )
        )

        XCTAssertTrue(
            TranscriptionManager.shouldUseDictionaryHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.65,
                maxActiveSignalRunDuration: 0.44
            )
        )

        XCTAssertFalse(
            TranscriptionManager.shouldUseDictionaryHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: true,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.70,
                maxActiveSignalRunDuration: 0.44
            )
        )
    }

    func testDictationPipelineSmokeEndToEndBoundaries() async throws {
        let initialSnapshot: PasteClipboardSnapshot.Snapshot = [[.string: Data("before".utf8)]]
        let dictionaryEntries = [DictionaryEntry(phrase: "Cueboard")]
        let listInput = "Need to do this one cue board two cue board"
        let expectedListOutput = "Need to do this:\n\n1. Cueboard\n2. Cueboard"

        // Scenario A: success path formatting + clipboard restore.
        do {
            let transcription = StubTranscriptionProvider(result: listInput)
            let clipboard = RecordingClipboardAdapter(snapshotToCapture: initialSnapshot)
            let recovery = RecordingFailureRecoveryController(executesRestoreImmediately: false)
            let injector = StubAccessibilityInjector(outcome: .verifiedSuccess)
            let coordinator = StubMenuFallbackCoordinator(result: .init(
                didMenuFallbackInsert: false,
                menuAttempt: nil,
                suppressFirstWarmupFailureWarning: false
            ))
            let pasteService = makePasteService(
                clipboard: clipboard,
                recovery: recovery,
                injector: injector,
                coordinator: coordinator
            )

            var spokenWordRecords: [String] = []
            let pipeline = DictationPipeline(
                transcriptionProvider: transcription,
                postProcessor: TranscriptionPostProcessor(),
                dictionaryEntriesProvider: { dictionaryEntries },
                autoParagraphsEnabledProvider: { true },
                listFormattingEnabledProvider: { true },
                listRenderModeProvider: { .multiline },
                recordSpokenWords: { spokenWordRecords.append($0) },
                pasteText: { pasteService.pasteText($0) }
            )

            let result = await runPipeline(pipeline)

            XCTAssertEqual(result.rawText, listInput)
            XCTAssertEqual(result.finalText, expectedListOutput)
            XCTAssertFalse(result.wasLikelyNoSpeech)
            XCTAssertEqual(transcription.autoParagraphFlags, [true])
            XCTAssertEqual(spokenWordRecords, [expectedListOutput])

            try await waitForCondition { clipboard.restoreCalls == 1 }

            XCTAssertEqual(clipboard.clipboardBefore, initialSnapshot)
            XCTAssertEqual(clipboard.pastedPayloads, [expectedListOutput])
            XCTAssertEqual(clipboard.clipboardAfter, initialSnapshot)
            XCTAssertEqual(recovery.cancelCalls, 1)
            XCTAssertEqual(recovery.startCalls, 0)
            XCTAssertEqual(coordinator.executeCalls, 0)
        }

        // Scenario B: paragraph formatting boundary stays intact.
        do {
            let paragraphInput = "First paragraph.\n\nSecond paragraph."
            let transcription = StubTranscriptionProvider(result: paragraphInput)
            var spokenWordRecords: [String] = []
            var pastedPayloads: [String] = []

            let pipeline = DictationPipeline(
                transcriptionProvider: transcription,
                postProcessor: TranscriptionPostProcessor(),
                dictionaryEntriesProvider: { [] },
                autoParagraphsEnabledProvider: { true },
                listFormattingEnabledProvider: { true },
                listRenderModeProvider: { .multiline },
                recordSpokenWords: { spokenWordRecords.append($0) },
                pasteText: { pastedPayloads.append($0) }
            )

            let result = await runPipeline(pipeline)

            XCTAssertEqual(result.finalText, paragraphInput)
            XCTAssertEqual(transcription.autoParagraphFlags, [true])
            XCTAssertEqual(spokenWordRecords, [paragraphInput])
            XCTAssertEqual(pastedPayloads, [paragraphInput])
        }

        // Scenario C: failure/non-pasteable path restores clipboard and exits cleanly.
        do {
            let transcription = StubTranscriptionProvider(result: listInput)
            let clipboard = RecordingClipboardAdapter(snapshotToCapture: initialSnapshot)
            let recovery = RecordingFailureRecoveryController(executesRestoreImmediately: true)
            let injector = StubAccessibilityInjector(outcome: .failureNeedsFallback)
            let coordinator = StubMenuFallbackCoordinator(result: .init(
                didMenuFallbackInsert: false,
                menuAttempt: .actionErrored,
                suppressFirstWarmupFailureWarning: false
            ))
            let pasteService = makePasteService(
                clipboard: clipboard,
                recovery: recovery,
                injector: injector,
                coordinator: coordinator
            )

            let pipeline = DictationPipeline(
                transcriptionProvider: transcription,
                postProcessor: TranscriptionPostProcessor(),
                dictionaryEntriesProvider: { dictionaryEntries },
                autoParagraphsEnabledProvider: { true },
                listFormattingEnabledProvider: { true },
                listRenderModeProvider: { .multiline },
                recordSpokenWords: { _ in },
                pasteText: { pasteService.pasteText($0) }
            )

            let result = await runPipeline(pipeline)

            XCTAssertEqual(result.finalText, expectedListOutput)
            XCTAssertFalse(result.wasLikelyNoSpeech)

            try await waitForCondition {
                recovery.startCalls == 1 && clipboard.restoreCalls == 1
            }

            XCTAssertEqual(clipboard.clipboardBefore, initialSnapshot)
            XCTAssertEqual(clipboard.clipboardAfter, initialSnapshot)
            XCTAssertEqual(clipboard.pastedPayloads, [expectedListOutput])
            XCTAssertEqual(coordinator.executeCalls, 1)
        }
    }

    func testDictationPipelineSmokeComposedFeaturesParagraphListCustomWords() async throws {
        let initialSnapshot: PasteClipboardSnapshot.Snapshot = [[.string: Data("before".utf8)]]
        let input = "project notes one cue board design two cue board review\n\nand we should meet at 415 pm"
        let expected = "project notes:\n\n1. Cueboard design\n2. Cueboard review\n\nAnd we should meet at 4:15 PM"
        let dictionaryEntries = [DictionaryEntry(phrase: "Cueboard")]

        let transcription = StubTranscriptionProvider(result: input)
        let clipboard = RecordingClipboardAdapter(snapshotToCapture: initialSnapshot)
        let recovery = RecordingFailureRecoveryController(executesRestoreImmediately: false)
        let injector = StubAccessibilityInjector(outcome: .verifiedSuccess)
        let coordinator = StubMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: nil,
            suppressFirstWarmupFailureWarning: false
        ))
        let pasteService = makePasteService(
            clipboard: clipboard,
            recovery: recovery,
            injector: injector,
            coordinator: coordinator
        )

        var spokenWordRecords: [String] = []
        let pipeline = DictationPipeline(
            transcriptionProvider: transcription,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { dictionaryEntries },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { true },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { spokenWordRecords.append($0) },
            pasteText: { pasteService.pasteText($0) }
        )

        let result = await runPipeline(pipeline)

        XCTAssertFalse(result.wasLikelyNoSpeech)
        XCTAssertEqual(result.finalText, expected)
        XCTAssertEqual(transcription.autoParagraphFlags, [true])
        XCTAssertEqual(spokenWordRecords, [expected])

        try await waitForCondition { clipboard.restoreCalls == 1 }

        XCTAssertEqual(clipboard.clipboardBefore, initialSnapshot)
        XCTAssertEqual(clipboard.pastedPayloads, [expected])
        XCTAssertEqual(clipboard.clipboardAfter, initialSnapshot)
        XCTAssertEqual(clipboard.restoreCalls, 1)
        XCTAssertEqual(recovery.startCalls, 0)
    }

    func testDictationPipelineKeepsPastePathWhenListFormattingDisabled() async throws {
        let initialSnapshot: PasteClipboardSnapshot.Snapshot = [[.string: Data("before".utf8)]]
        let input = "Need to do this one cue board two cue board"
        let expected = "Need to do this one Cueboard two Cueboard"
        let dictionaryEntries = [DictionaryEntry(phrase: "Cueboard")]

        let transcription = StubTranscriptionProvider(result: input)
        let clipboard = RecordingClipboardAdapter(snapshotToCapture: initialSnapshot)
        let recovery = RecordingFailureRecoveryController(executesRestoreImmediately: false)
        let injector = StubAccessibilityInjector(outcome: .verifiedSuccess)
        let coordinator = StubMenuFallbackCoordinator(result: .init(
            didMenuFallbackInsert: false,
            menuAttempt: nil,
            suppressFirstWarmupFailureWarning: false
        ))
        let pasteService = makePasteService(
            clipboard: clipboard,
            recovery: recovery,
            injector: injector,
            coordinator: coordinator
        )

        var spokenWordRecords: [String] = []
        let pipeline = DictationPipeline(
            transcriptionProvider: transcription,
            postProcessor: TranscriptionPostProcessor(),
            dictionaryEntriesProvider: { dictionaryEntries },
            autoParagraphsEnabledProvider: { true },
            listFormattingEnabledProvider: { false },
            listRenderModeProvider: { .multiline },
            recordSpokenWords: { spokenWordRecords.append($0) },
            pasteText: { pasteService.pasteText($0) }
        )

        let result = await runPipeline(pipeline)

        XCTAssertFalse(result.wasLikelyNoSpeech)
        XCTAssertEqual(result.finalText, expected)
        XCTAssertEqual(spokenWordRecords, [expected])

        try await waitForCondition { clipboard.restoreCalls == 1 }

        XCTAssertEqual(clipboard.clipboardBefore, initialSnapshot)
        XCTAssertEqual(clipboard.pastedPayloads, [expected])
        XCTAssertEqual(clipboard.clipboardAfter, initialSnapshot)
        XCTAssertEqual(recovery.startCalls, 0)
    }

    func testDictationPipelineSuppressesDictionaryPromptEchoHallucination() async {
        let dictionaryEntries = [
            DictionaryEntry(phrase: "MiGo"),
            DictionaryEntry(phrase: "KeyVox"),
            DictionaryEntry(phrase: "Dom Esposito"),
            DictionaryEntry(phrase: "Cueboard"),
            DictionaryEntry(phrase: "main"),
            DictionaryEntry(phrase: "cue"),
            DictionaryEntry(phrase: "subcue")
        ]

        let oneWordSpam = """
        MiGo, KeyVox, KeyVox, KeyVox, Dom Esposito, Cueboard, main, cue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue
        """
        let longSilenceNoiseSpam = """
        Vox, KeyVox, KeyVox, KeyVox, Dom Esposito, Cueboard, main, cue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, subcue, ee, ee, ee, ee, ee, ee, ee, ee, ee, ee, ee, ee, ee, ee, ee
        """

        for spam in [oneWordSpam, longSilenceNoiseSpam] {
            let transcription = StubTranscriptionProvider(result: spam)
            var spokenWordRecords: [String] = []
            var pastedPayloads: [String] = []

            let pipeline = DictationPipeline(
                transcriptionProvider: transcription,
                postProcessor: TranscriptionPostProcessor(),
                dictionaryEntriesProvider: { dictionaryEntries },
                autoParagraphsEnabledProvider: { true },
                listFormattingEnabledProvider: { true },
                listRenderModeProvider: { .multiline },
                recordSpokenWords: { spokenWordRecords.append($0) },
                pasteText: { pastedPayloads.append($0) }
            )

            let result = await runPipeline(pipeline, useDictionaryHintPrompt: true)

            XCTAssertTrue(result.wasLikelyNoSpeech)
            XCTAssertEqual(result.finalText, "")
            XCTAssertEqual(spokenWordRecords, [])
            XCTAssertEqual(pastedPayloads, [])
            XCTAssertEqual(transcription.useDictionaryHintPromptFlags, [true])
        }
    }

    private func runPipeline(
        _ pipeline: DictationPipeline,
        frames: [Float] = [0.1, 0.2, 0.3],
        useDictionaryHintPrompt: Bool = true
    ) async -> DictationPipelineResult {
        await withCheckedContinuation { continuation in
            pipeline.run(
                audioFrames: frames,
                useDictionaryHintPrompt: useDictionaryHintPrompt
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    private func makePasteService(
        clipboard: RecordingClipboardAdapter,
        recovery: RecordingFailureRecoveryController,
        injector: StubAccessibilityInjector,
        coordinator: StubMenuFallbackCoordinator
    ) -> PasteService {
        let service = PasteService(
            pasteQueue: DispatchQueue(label: "DictationPipelineSmokeTests.queue.\(UUID().uuidString)"),
            heuristicTTL: 10,
            restoreDelayAfterMenuFallback: 0,
            restoreDelayAfterAccessibilityInjection: 0,
            menuFallbackVerificationTimeout: 0.01,
            menuFallbackVerificationPollInterval: 0.001,
            frontmostAppIdentityProvider: { PasteAppIdentity(bundleID: "com.example.app", pid: 777) },
            clockNow: Date.init,
            clipboardAdapter: clipboard,
            failureRecoveryController: recovery,
            axInspector: NoopAXInspector(),
            accessibilityInjector: injector,
            menuFallbackExecutor: NoopFallbackExecutor(),
            menuFallbackCoordinator: coordinator,
            spacingHeuristics: PassthroughSpacingHeuristics()
        )
        Self.retainedServices.append(service)
        return service
    }
}

private final class StubTranscriptionProvider: DictationTranscriptionProviding {
    private let result: String?
    var lastResultWasLikelyNoSpeech: Bool
    private(set) var autoParagraphFlags: [Bool] = []
    private(set) var useDictionaryHintPromptFlags: [Bool] = []

    init(result: String?, lastResultWasLikelyNoSpeech: Bool = false) {
        self.result = result
        self.lastResultWasLikelyNoSpeech = lastResultWasLikelyNoSpeech
    }

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (String?) -> Void
    ) {
        _ = audioFrames
        useDictionaryHintPromptFlags.append(useDictionaryHintPrompt)
        autoParagraphFlags.append(enableAutoParagraphs)
        completion(result)
    }
}

private final class RecordingClipboardAdapter: PasteClipboardAdapting {
    private let snapshotToCapture: PasteClipboardSnapshot.Snapshot
    private(set) var clipboardBefore: PasteClipboardSnapshot.Snapshot?
    private(set) var pastedPayloads: [String] = []
    private(set) var clipboardAfter: PasteClipboardSnapshot.Snapshot?
    private(set) var restoreCalls = 0

    init(snapshotToCapture: PasteClipboardSnapshot.Snapshot) {
        self.snapshotToCapture = snapshotToCapture
    }

    func captureSnapshot() -> PasteClipboardSnapshot.Snapshot {
        clipboardBefore = snapshotToCapture
        return snapshotToCapture
    }

    func setString(_ text: String) {
        pastedPayloads.append(text)
    }

    func restore(_ snapshot: PasteClipboardSnapshot.Snapshot) {
        restoreCalls += 1
        clipboardAfter = snapshot
    }
}

private final class RecordingFailureRecoveryController: PasteFailureRecoveryControlling {
    private let executesRestoreImmediately: Bool
    private(set) var cancelCalls = 0
    private(set) var startCalls = 0

    init(executesRestoreImmediately: Bool) {
        self.executesRestoreImmediately = executesRestoreImmediately
    }

    func cancelActiveRecoveryIfNeeded() {
        cancelCalls += 1
    }

    func startRecovery(restoreClipboard: @escaping () -> Void) {
        startCalls += 1
        if executesRestoreImmediately {
            restoreClipboard()
        }
    }
}

private final class PassthroughSpacingHeuristics: PasteSpacingHeuristicApplying {
    func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> String {
        _ = currentIdentity
        _ = lastInsertionAppIdentity
        _ = lastInsertionAt
        _ = lastInsertedTrailingCharacter
        _ = identityMatcher
        return text
    }
}

private final class StubAccessibilityInjector: PasteAccessibilityInjecting {
    private let outcome: PasteAccessibilityInjectionOutcome

    init(outcome: PasteAccessibilityInjectionOutcome) {
        self.outcome = outcome
    }

    func injectTextViaAccessibility(_ text: String) -> PasteAccessibilityInjectionOutcome {
        _ = text
        return outcome
    }
}

private final class StubMenuFallbackCoordinator: PasteMenuFallbackCoordinating {
    private let result: PasteMenuFallbackExecutionResult
    private(set) var executeCalls = 0

    init(result: PasteMenuFallbackExecutionResult) {
        self.result = result
    }

    func executeMenuFallback(
        insertionText: String,
        didAccessibilityInsertText: Bool,
        targetAppIdentity: PasteAppIdentity?,
        menuFallbackExecutor: PasteMenuFallbackExecuting,
        shouldTrustMenuSuccessWithoutAXVerification: () -> Bool,
        setClipboardStringOnMainThread: (String) -> Void,
        typeLeadingSpacesOnMainThread: (Int) -> Bool
    ) -> PasteMenuFallbackExecutionResult {
        _ = insertionText
        _ = didAccessibilityInsertText
        _ = targetAppIdentity
        _ = menuFallbackExecutor
        _ = shouldTrustMenuSuccessWithoutAXVerification
        _ = setClipboardStringOnMainThread
        _ = typeLeadingSpacesOnMainThread
        executeCalls += 1
        return result
    }
}

private final class NoopFallbackExecutor: PasteMenuFallbackExecuting {
    func pasteViaMenuBarOnMainThread() -> PasteMenuFallbackAttemptResult { .unavailable }
    func frontmostProcessIDOnMainThread() -> pid_t? { nil }
    func captureVerificationContext() -> PasteMenuFallbackVerificationContext? { nil }
    func verifyInsertion(using context: PasteMenuFallbackVerificationContext?) -> Bool {
        _ = context
        return false
    }
    func captureUndoStateOnMainThread() -> PasteMenuFallbackUndoState? { nil }
    func verifyInsertionWithoutAXContextOnMainThread(initialUndoState: PasteMenuFallbackUndoState?) -> Bool {
        _ = initialUndoState
        return false
    }
    func startLiveValueChangeVerificationSession(processID: pid_t?) -> PasteAXLiveSessioning? {
        _ = processID
        return nil
    }
    func verifyInsertionUsingLiveValueChangeSession(_ session: PasteAXLiveSessioning?) -> Bool {
        _ = session
        return false
    }
    func finishLiveValueChangeVerificationSession(_ session: PasteAXLiveSessioning?) {
        _ = session
    }
}

private final class NoopAXInspector: PasteAXInspecting {
    func focusedInsertionContext() -> PasteInsertionContext? { nil }
    func focusedUIElement() -> AXUIElement? { nil }
    func roleString(for element: AXUIElement) -> String? {
        _ = element
        return nil
    }
    func selectedRange(for element: AXUIElement) -> CFRange? {
        _ = element
        return nil
    }
    func stringForRange(_ range: CFRange, element: AXUIElement) -> String? {
        _ = range
        _ = element
        return nil
    }
    func previousCharacterFromValueAttribute(element: AXUIElement, caretLocation: Int) -> Character? {
        _ = element
        _ = caretLocation
        return nil
    }
    func valueLengthForMenuVerification(element: AXUIElement) -> Int? {
        _ = element
        return nil
    }
    func candidateVerificationElements(
        for pid: pid_t,
        maxDepth: Int,
        maxNodes: Int,
        maxCandidates: Int
    ) -> [AXUIElement] {
        _ = pid
        _ = maxDepth
        _ = maxNodes
        _ = maxCandidates
        return []
    }
}
