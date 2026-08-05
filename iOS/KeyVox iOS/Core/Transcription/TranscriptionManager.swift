import Combine
import Foundation
import KeyVoxCore

@MainActor
final class TranscriptionManager: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case processingCapture
        case transcribing
    }

    @Published var state: State = .idle
    @Published var isSessionActive = false
    @Published var sessionDisablePending = false
    @Published var sessionExpirationDate: Date?
    @Published var lastErrorMessage: String?
    @Published var lastTranscriptionText: String?
    @Published private(set) var isModelAvailable = false
    @Published private(set) var hasPendingInterruptedCaptureRecovery = false
    @Published var isRecoveringInterruptedCapture = false
    @Published var isReturnToHostViewPresented = false

    let recorder: any AudioRecording
    let transcriptionService: any DictationProvider
    let dictionaryStore: DictionaryStore
    private let weeklyWordStatsStore: WeeklyWordStatsStore
    private let postProcessor: TranscriptionPostProcessor
    let keyboardBridge: KeyVoxKeyboardBridge
    let interruptedCaptureRecoveryStore: InterruptedCaptureRecoveryStore
    private let modelPathProvider: () -> String?
    private let modelAvailabilityProvider: () -> Bool
    private let missingModelMessageProvider: () -> String
    private let autoParagraphsEnabledProvider: () -> Bool
    private let listFormattingEnabledProvider: () -> Bool
    private let capsLockEnabledProvider: () -> Bool
    private let processOutputText: (DictationPipelineTextProcessingContext) async -> DictationPipelineTextProcessingResult
    private let recordPipelineResult: (DictationPipelineResult, String) -> Void
    private let recordSuccessfulDictation: () -> Void
    private let prewarmStyleRewriteForUpcomingDictation: () -> Void
    let releaseStyleRewritePrewarmSession: @MainActor (String) async -> Void
    private let sessionDisableTimingProvider: (() -> SessionDisableTiming)?
    let isTTSPlaybackActiveProvider: () -> Bool
    let sessionPolicy: SessionPolicy

    private var cancellables = Set<AnyCancellable>()
    var pendingPipelineOutputText: String?
    var idleTimeoutTask: Task<Void, Never>?
    var utteranceSafetyTask: Task<Void, Never>?
    var activeUtteranceID = UUID()
    var activeInterruptedCaptureRecoveryID: UUID?

    lazy var dictationPipeline = DictationPipeline(
        transcriptionProvider: transcriptionService,
        postProcessor: postProcessor,
        dictionaryEntriesProvider: { [weak self] in
            self?.dictionaryStore.entries ?? []
        },
        autoParagraphsEnabledProvider: { [weak self] in
            self?.autoParagraphsEnabledProvider() ?? true
        },
        listFormattingEnabledProvider: { [weak self] in
            self?.listFormattingEnabledProvider() ?? true
        },
        capsLockEnabledProvider: { [weak self] in
            self?.capsLockEnabledProvider() ?? false
        },
        listRenderModeProvider: { .multiline },
        recordSpokenWords: { [weak self] text in
            self?.weeklyWordStatsStore.recordSpokenWords(from: text)
            self?.recordSuccessfulDictation()
        },
        pasteText: { [weak self] text in
            self?.capturePipelineOutput(text)
        },
        processOutputTextWithContext: { [weak self] context in
            await self?.processOutputText(context) ?? .unchanged(context.baseText)
        }
    )

    func runDictationPipeline(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool
    ) async -> DictationPipelineResult {
        await withCheckedContinuation { continuation in
            dictationPipeline.run(
                audioFrames: audioFrames,
                useDictionaryHintPrompt: useDictionaryHintPrompt
            ) { result in
                continuation.resume(returning: result)
            }
        }
    }

    init(
        recorder: any AudioRecording,
        transcriptionService: any DictationProvider,
        dictionaryStore: DictionaryStore,
        weeklyWordStatsStore: WeeklyWordStatsStore,
        postProcessor: TranscriptionPostProcessor,
        keyboardBridge: KeyVoxKeyboardBridge,
        interruptedCaptureRecoveryStore: InterruptedCaptureRecoveryStore,
        modelPathProvider: @escaping () -> String?,
        modelAvailabilityProvider: (() -> Bool)? = nil,
        missingModelMessageProvider: (() -> String)? = nil,
        autoParagraphsEnabledProvider: @escaping () -> Bool = { true },
        listFormattingEnabledProvider: @escaping () -> Bool = { true },
        capsLockEnabledProvider: @escaping () -> Bool = { false },
        processOutputTextWithContext: @escaping (DictationPipelineTextProcessingContext) async -> DictationPipelineTextProcessingResult = {
            .unchanged($0.baseText)
        },
        recordPipelineResult: @escaping (DictationPipelineResult, String) -> Void = { _, _ in },
        recordSuccessfulDictation: @escaping () -> Void = {},
        prewarmStyleRewriteForUpcomingDictation: @escaping () -> Void = {},
        releaseStyleRewritePrewarmSession: @escaping @MainActor (String) async -> Void = { _ in },
        sessionDisableTimingProvider: (() -> SessionDisableTiming)? = nil,
        isTTSPlaybackActiveProvider: @escaping () -> Bool = { false },
        sessionDisableTimingPublisher: AnyPublisher<SessionDisableTiming, Never> = Empty().eraseToAnyPublisher(),
        sessionPolicy: SessionPolicy = .default
    ) {
        self.recorder = recorder
        self.transcriptionService = transcriptionService
        self.dictionaryStore = dictionaryStore
        self.weeklyWordStatsStore = weeklyWordStatsStore
        self.postProcessor = postProcessor
        self.keyboardBridge = keyboardBridge
        self.interruptedCaptureRecoveryStore = interruptedCaptureRecoveryStore
        self.modelPathProvider = modelPathProvider
        self.modelAvailabilityProvider = modelAvailabilityProvider ?? {
            guard let path = modelPathProvider()?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty else {
                return false
            }
            return FileManager.default.fileExists(atPath: path)
        }
        self.missingModelMessageProvider = missingModelMessageProvider ?? {
            "Whisper model not found in App Group container."
        }
        self.autoParagraphsEnabledProvider = autoParagraphsEnabledProvider
        self.listFormattingEnabledProvider = listFormattingEnabledProvider
        self.capsLockEnabledProvider = capsLockEnabledProvider
        self.processOutputText = processOutputTextWithContext
        self.recordPipelineResult = recordPipelineResult
        self.recordSuccessfulDictation = recordSuccessfulDictation
        self.prewarmStyleRewriteForUpcomingDictation = prewarmStyleRewriteForUpcomingDictation
        self.releaseStyleRewritePrewarmSession = releaseStyleRewritePrewarmSession
        self.sessionDisableTimingProvider = sessionDisableTimingProvider
        self.isTTSPlaybackActiveProvider = isTTSPlaybackActiveProvider
        self.sessionPolicy = sessionPolicy

        bindDictionaryState()
        bindSessionDisableTimingState(sessionDisableTimingPublisher)
        refreshModelAvailability()
        isSessionActive = recorder.isMonitoring
        lastTranscriptionText = KeyVoxIPCBridge.latestTranscription()
        hasPendingInterruptedCaptureRecovery = interruptedCaptureRecoveryStore.load() != nil

        if isSessionActive {
            armIdleTimeout()
        }
    }

    func handleAppDidEnterBackground() {
        isReturnToHostViewPresented = false
    }

    func handleEnableSessionCommand() {
        Task { await performEnableSessionCommand() }
    }

    func handleDisableSessionCommand() {
        Task { await performDisableSessionCommand() }
    }

    func handleToggleSessionCommand() {
        Task {
            if isSessionActive && !sessionDisablePending {
                await performDisableSessionCommand()
            } else {
                await performEnableSessionCommand()
            }
        }
    }

    func cancelCurrentUtterance() {
        Task { await performCancelCurrentUtterance() }
    }

    func handleStartRecordingCommand(isFromURL: Bool = false) {
        Task { await performStartRecordingCommand(isFromURL: isFromURL) }
    }

    func handleStopRecordingCommand() {
        Task { await performStopRecordingCommand() }
    }

    func performEnableSessionCommand() async {
        guard !isSessionActive else { return }
        lastErrorMessage = nil

        do {
            try await recorder.enableMonitoring()
            isSessionActive = true
            sessionDisablePending = false
            armIdleTimeout()
        } catch {
            lastErrorMessage = error.localizedDescription
            isSessionActive = false
            sessionDisablePending = false
            cancelIdleTimeout()
        }
    }

    func performDisableSessionCommand() async {
        guard isSessionActive else { return }

        if state == .idle {
            await completeSessionShutdown()
            return
        }

        sessionDisablePending = true
        cancelIdleTimeout()
        await performCancelCurrentUtterance()
    }

    func performStartRecordingCommand(isFromURL: Bool = false) async {
        guard state == .idle else { return }
        state = .recording
        lastErrorMessage = nil
        pendingPipelineOutputText = nil
        activeUtteranceID = UUID()
        refreshModelAvailability()
        cancelIdleTimeout()

        if isFromURL {
            isReturnToHostViewPresented = true
        }

        do {
            try await recorder.startRecording()
            isSessionActive = true
            sessionDisablePending = false
            keyboardBridge.publishRecordingStarted()
            armUtteranceSafetyWatchdog(for: activeUtteranceID)
            prewarmStyleRewriteForUpcomingDictation()
        } catch {
            state = .idle
            lastErrorMessage = error.localizedDescription
            keyboardBridge.publishNoSpeech()
            await finishAndDisableSessionIfNeeded()
        }
    }

    func repairMonitoringSessionIfNeeded() async {
        guard state == .idle else { return }
        guard sessionDisablePending == false else { return }

        do {
            try await recorder.repairMonitoringAfterPlayback()
            isSessionActive = recorder.isMonitoring
            if isSessionActive {
                armIdleTimeout()
            }
        } catch {
            lastErrorMessage = error.localizedDescription
            isSessionActive = recorder.isMonitoring
        }
    }

    func performStopRecordingCommand() async {
        guard state == .recording else { return }
        let utteranceID = activeUtteranceID
        cancelUtteranceSafetyWatchdog()
        state = .processingCapture
        let startTime = Date()

        #if DEBUG
        print("--- Speed Profile Start ---")
        #endif

        let stoppedCapture = await recorder.stopRecording()
        await completeStopRecording(stoppedCapture, utteranceID: utteranceID, startTime: startTime)
    }

    func completeStopRecording(_ stoppedCapture: StoppedCapture, utteranceID: UUID, startTime: Date) async {
        guard utteranceID == activeUtteranceID else {
            await releaseStyleRewritePrewarmSession("stale-utterance")
            await finishAndDisableSessionIfNeeded()
            return
        }

        guard !stoppedCapture.outputFrames.isEmpty else {
            await releaseStyleRewritePrewarmSession("empty-capture")
            state = .idle
            keyboardBridge.publishNoSpeech()
            await finishAndDisableSessionIfNeeded()
            return
        }

        refreshModelAvailability()
        guard isModelAvailable else {
            await releaseStyleRewritePrewarmSession("dictation-model-unavailable")
            lastErrorMessage = missingModelMessageProvider()
            state = .idle
            keyboardBridge.publishNoSpeech()
            await finishAndDisableSessionIfNeeded()
            return
        }

        transcriptionService.warmup()

        let usedDictionaryHintPrompt = DictionaryHintPromptGate.shouldUseHintPrompt(
            lastCaptureHadActiveSignal: recorder.lastCaptureHadActiveSignal,
            lastCaptureWasLikelySilence: recorder.lastCaptureWasLikelySilence,
            lastCaptureWasLongTrueSilence: recorder.lastCaptureWasLongTrueSilence,
            lastCaptureDuration: recorder.lastCaptureDuration,
            maxActiveSignalRunDuration: recorder.maxActiveSignalRunDuration
        )

        pendingPipelineOutputText = nil
        state = .transcribing
        keyboardBridge.publishTranscribing()

        let result = await runDictationPipeline(
            audioFrames: stoppedCapture.outputFrames,
            useDictionaryHintPrompt: usedDictionaryHintPrompt
        )

        guard utteranceID == activeUtteranceID else {
            await releaseStyleRewritePrewarmSession("stale-result")
            return
        }

        let finalText = pendingPipelineOutputText ?? result.finalText
        #if DEBUG
        print("2. Provider inference: \(String(format: "%.3f", result.inferenceDuration))s")
        logTextTransformationSpeedProfile(result)
        #endif
        pendingPipelineOutputText = nil
        lastErrorMessage = nil
        state = .idle
        recordPipelineResult(result, finalText)

        if result.wasLikelyNoSpeech || finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            #if DEBUG
            print("4. Injection trigger: \(String(format: "%.3f", result.pasteDuration))s")
            let totalTime = Date().timeIntervalSince(startTime)
            print("Total end-to-end latency: \(String(format: "%.3f", totalTime))s")
            print("--- Speed Profile End ---")
            #endif
            keyboardBridge.publishNoSpeech()
        } else {
            #if DEBUG
            print("4. Injection trigger: \(String(format: "%.3f", result.pasteDuration))s")
            let totalTime = Date().timeIntervalSince(startTime)
            print("Total end-to-end latency: \(String(format: "%.3f", totalTime))s")
            print("--- Speed Profile End ---")
            #endif
            lastTranscriptionText = finalText
            keyboardBridge.publishTranscriptionReady(finalText)
        }

        await releaseStyleRewritePrewarmSession("utterance-finished")
        await finishAndDisableSessionIfNeeded()
    }

    private func bindDictionaryState() {
        updateDictionaryState(entries: dictionaryStore.entries)

        dictionaryStore.$entries
            .sink { [weak self] entries in
                self?.updateDictionaryState(entries: entries)
            }
            .store(in: &cancellables)
    }

    private func updateDictionaryState(entries: [DictionaryEntry]) {
        postProcessor.updateDictionaryEntries(entries)
    }

    private func bindSessionDisableTimingState(_ publisher: AnyPublisher<SessionDisableTiming, Never>) {
        publisher
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] timing in
                Task { @MainActor [weak self] in
                    await self?.handleSessionDisableTimingChanged(to: timing)
                }
            }
            .store(in: &cancellables)
    }

    func currentSessionDisableTiming() -> SessionDisableTiming? {
        sessionDisableTimingProvider?()
    }

    func currentIdleTimeout(timing: SessionDisableTiming? = nil) -> TimeInterval? {
        if let timing {
            return timing.idleTimeout
        }

        if let currentTiming = currentSessionDisableTiming() {
            return currentTiming.idleTimeout
        }

        return sessionPolicy.idleTimeout
    }

    func shouldDisableSessionImmediatelyWhenIdle(timing: SessionDisableTiming? = nil) -> Bool {
        (timing ?? currentSessionDisableTiming()) == .immediately
    }

    func refreshModelAvailability() {
        isModelAvailable = modelAvailabilityProvider()
    }

    private func capturePipelineOutput(_ text: String) {
        pendingPipelineOutputText = text
    }

    #if DEBUG
    private func logTextTransformationSpeedProfile(_ result: DictationPipelineResult) {
        let duration = String(format: "%.3f", result.textTransformationDuration)
        let style = result.textTransformationStyleIdentifier ?? "none"
        let mode = result.textTransformationProcessingMode.map { " mode=\($0)" } ?? ""
        let chunkSummary = " style=\(style)\(mode) chunks=\(result.textTransformationChunkCount)"
        let finalTextSuffix = rawDebugTextLoggingEnabled
            ? " finalText=\(escapedDebugText(result.finalText))"
            : ""
        if let errorDescription = result.textTransformationErrorDescription {
            print(
                "3. Text transformation: \(duration)s " +
                "applied=false error=\(errorDescription)" +
                chunkSummary +
                finalTextSuffix
            )
        } else {
            print(
                "3. Text transformation: \(duration)s " +
                "applied=\(result.textTransformationApplied)" +
                chunkSummary +
                finalTextSuffix
            )
        }
    }

    private var rawDebugTextLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"
    }

    private func escapedDebugText(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: "\\n")
    }
    #endif

    func setInterruptedCaptureRecoveryPresence(_ isPresent: Bool) {
        hasPendingInterruptedCaptureRecovery = isPresent
    }

}
