import Combine
import Foundation
import KeyVoxCore

@MainActor
final class iOSTranscriptionManager: ObservableObject {
    enum State: Equatable {
        case idle
        case recording
        case processingCapture
        case transcribing
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var lastCaptureArtifact: Phase2CaptureArtifact?
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var lastTranscriptionSnapshot: iOSTranscriptionDebugSnapshot?
    @Published private(set) var isModelAvailable = false

    private let recorder: any iOSAudioRecording
    private let artifactWriter: any Phase2CaptureArtifactWriting
    private let transcriptionService: any iOSDictationService
    private let dictionaryStore: DictionaryStore
    private let postProcessor: TranscriptionPostProcessor
    private let keyboardBridge: KeyVoxKeyboardBridge
    private let modelPathProvider: () -> String?
    private let autoParagraphsEnabledProvider: () -> Bool
    private let listFormattingEnabledProvider: () -> Bool

    private var cancellables = Set<AnyCancellable>()
    private var pendingPipelineOutputText: String?

    private lazy var dictationPipeline = DictationPipeline(
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
        capsLockEnabledProvider: { false },
        listRenderModeProvider: { .multiline },
        recordSpokenWords: { _ in },
        pasteText: { [weak self] text in
            self?.capturePipelineOutput(text)
        }
    )

    init(
        recorder: any iOSAudioRecording,
        artifactWriter: any Phase2CaptureArtifactWriting,
        transcriptionService: any iOSDictationService,
        dictionaryStore: DictionaryStore,
        postProcessor: TranscriptionPostProcessor,
        keyboardBridge: KeyVoxKeyboardBridge,
        modelPathProvider: @escaping () -> String?,
        autoParagraphsEnabledProvider: @escaping () -> Bool = { true },
        listFormattingEnabledProvider: @escaping () -> Bool = { true }
    ) {
        self.recorder = recorder
        self.artifactWriter = artifactWriter
        self.transcriptionService = transcriptionService
        self.dictionaryStore = dictionaryStore
        self.postProcessor = postProcessor
        self.keyboardBridge = keyboardBridge
        self.modelPathProvider = modelPathProvider
        self.autoParagraphsEnabledProvider = autoParagraphsEnabledProvider
        self.listFormattingEnabledProvider = listFormattingEnabledProvider

        bindDictionaryState()
        refreshModelAvailability()
        
        if isModelAvailable {
            transcriptionService.warmup()
        }
    }

    func handleStartRecordingCommand() {
        Task { await performStartRecordingCommand() }
    }

    func handleStopRecordingCommand() {
        Task { await performStopRecordingCommand() }
    }

    func performStartRecordingCommand() async {
        guard state == .idle else { return }
        state = .recording
        lastErrorMessage = nil
        lastTranscriptionSnapshot = nil
        pendingPipelineOutputText = nil
        refreshModelAvailability()

        do {
            try await recorder.startRecording()
            keyboardBridge.publishRecordingStarted()
        } catch {
            state = .idle
            lastErrorMessage = error.localizedDescription
            keyboardBridge.publishNoSpeech()
        }
    }

    func performStopRecordingCommand() async {
        guard state == .recording else { return }
        state = .processingCapture
        let startTime = Date()

        #if DEBUG
        print("--- Speed Profile Start ---")
        #endif

        let stoppedCapture = await recorder.stopRecording()
        let request = Phase2CaptureWriteRequest(
            capturedAt: Date(),
            sampleRate: 16000,
            snapshotFrames: stoppedCapture.snapshot,
            outputFrames: stoppedCapture.outputFrames,
            captureDuration: stoppedCapture.captureDuration,
            hadActiveSignal: recorder.lastCaptureHadActiveSignal,
            wasAbsoluteSilence: recorder.lastCaptureWasAbsoluteSilence,
            wasLikelySilence: recorder.lastCaptureWasLikelySilence,
            wasLongTrueSilence: recorder.lastCaptureWasLongTrueSilence,
            maxActiveSignalRunDuration: recorder.maxActiveSignalRunDuration,
            currentCaptureDeviceName: recorder.currentCaptureDeviceName
        )

        do {
            lastCaptureArtifact = try await artifactWriter.writeLatestCapture(request)
        } catch {
            lastErrorMessage = error.localizedDescription
        }

        guard !stoppedCapture.outputFrames.isEmpty else {
            lastTranscriptionSnapshot = nil
            state = .idle
            keyboardBridge.publishNoSpeech()
            return
        }

        refreshModelAvailability()
        guard isModelAvailable else {
            lastTranscriptionSnapshot = nil
            lastErrorMessage = "Whisper model not found in App Group container."
            state = .idle
            keyboardBridge.publishNoSpeech()
            return
        }

        transcriptionService.warmup()

        let usedDictionaryHintPrompt = !dictionaryStore.entries.isEmpty && DictionaryHintPromptGate.shouldUseHintPrompt(
            lastCaptureHadActiveSignal: recorder.lastCaptureHadActiveSignal,
            lastCaptureWasLikelySilence: recorder.lastCaptureWasLikelySilence,
            lastCaptureWasLongTrueSilence: recorder.lastCaptureWasLongTrueSilence,
            lastCaptureDuration: recorder.lastCaptureDuration,
            maxActiveSignalRunDuration: recorder.maxActiveSignalRunDuration
        )

        pendingPipelineOutputText = nil
        state = .transcribing
        keyboardBridge.publishTranscribing()

        dictationPipeline.run(
            audioFrames: stoppedCapture.outputFrames,
            useDictionaryHintPrompt: usedDictionaryHintPrompt
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let finalText = self.pendingPipelineOutputText ?? result.finalText
                #if DEBUG
                print("2. Whisper inference: \(String(format: "%.3f", result.inferenceDuration))s")
                #endif
                self.lastTranscriptionSnapshot = iOSTranscriptionDebugSnapshot(
                    rawText: result.rawText,
                    finalText: finalText,
                    wasLikelyNoSpeech: result.wasLikelyNoSpeech,
                    inferenceDuration: result.inferenceDuration,
                    pasteDuration: result.pasteDuration,
                    usedDictionaryHintPrompt: usedDictionaryHintPrompt,
                    captureDuration: self.recorder.lastCaptureDuration,
                    outputFrameCount: stoppedCapture.outputFrames.count
                )
                self.pendingPipelineOutputText = nil
                self.lastErrorMessage = nil
                self.state = .idle

                if result.wasLikelyNoSpeech || finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    #if DEBUG
                    print("3. Injection trigger: \(String(format: "%.3f", result.pasteDuration))s")
                    let totalTime = Date().timeIntervalSince(startTime)
                    print("Total end-to-end latency: \(String(format: "%.3f", totalTime))s")
                    print("--- Speed Profile End ---")
                    #endif
                    self.keyboardBridge.publishNoSpeech()
                } else {
                    #if DEBUG
                    print("3. Injection trigger: \(String(format: "%.3f", result.pasteDuration))s")
                    let totalTime = Date().timeIntervalSince(startTime)
                    print("Total end-to-end latency: \(String(format: "%.3f", totalTime))s")
                    print("--- Speed Profile End ---")
                    #endif
                    self.keyboardBridge.publishTranscriptionReady(finalText)
                }
            }
        }
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
        transcriptionService.updateDictionaryHintPrompt(whisperHintPrompt(for: entries))
    }

    private func refreshModelAvailability() {
        guard let path = modelPathProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !path.isEmpty else {
            isModelAvailable = false
            return
        }

        isModelAvailable = FileManager.default.fileExists(atPath: path)
    }

    private func capturePipelineOutput(_ text: String) {
        pendingPipelineOutputText = text
    }

    private func whisperHintPrompt(for entries: [DictionaryEntry], maxEntries: Int = 200, maxChars: Int = 1200) -> String {
        let candidates = entries
            .map(\.phrase)
            .filter { !$0.isEmpty }
            .suffix(maxEntries)

        guard !candidates.isEmpty else { return "" }

        var prompt = "Domain vocabulary: "
        var appendedCount = 0
        for phrase in candidates {
            let separator = prompt == "Domain vocabulary: " ? "" : ", "
            let chunk = separator + phrase
            if prompt.count + chunk.count > maxChars {
                break
            }
            prompt += chunk
            appendedCount += 1
        }

        return appendedCount == 0 ? "" : prompt
    }
}
