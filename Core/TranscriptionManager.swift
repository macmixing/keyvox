import SwiftUI
import Combine
import ApplicationServices

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

private enum DictationPromptEchoGuard {
    nonisolated static func shouldTreatAsNoSpeech(
        processedText: String,
        dictionaryEntries: [DictionaryEntry],
        usedDictionaryHintPrompt: Bool
    ) -> Bool {
        guard usedDictionaryHintPrompt else { return false }

        let normalizedPhrases = dictionaryEntries
            .map { normalizeForMatching($0.phrase) }
            .filter { !$0.isEmpty }
        guard !normalizedPhrases.isEmpty else { return false }

        let chunks = splitChunks(processedText)
        guard chunks.count >= 10 else { return false }

        let dictionaryChunkMatches = chunks.reduce(0) { count, chunk in
            let matchesDictionaryPhrase = normalizedPhrases.contains { phrase in
                chunk == phrase || chunk.contains(phrase)
            }
            return count + (matchesDictionaryPhrase ? 1 : 0)
        }

        let dictionaryChunkRatio = Float(dictionaryChunkMatches) / Float(chunks.count)
        let hasDictionaryChunkFlood = dictionaryChunkRatio >= 0.72

        let modeChunkCount = mostCommonCount(in: chunks)
        let longestRepeatedRun = longestConsecutiveRun(in: chunks)
        let uniqueChunkCount = Set(chunks).count
        let hasLowDiversitySpam = uniqueChunkCount <= max(4, chunks.count / 5)
        let hasRunawayRepetition = longestRepeatedRun >= 6 || modeChunkCount >= max(8, chunks.count / 2)
        let dictionaryWords = Set(normalizedPhrases.flatMap { phrase in
            phrase.split(separator: " ").map(String.init)
        })
        let chunkRuns = consecutiveRuns(in: chunks)
        let hasDictionaryRepeatedRun = chunkRuns.contains { run in
            guard run.count >= 6 else { return false }
            return normalizedPhrases.contains(where: { run.value == $0 || run.value.contains($0) })
                || dictionaryWords.contains(run.value)
        }
        let hasShortNoiseRun = chunkRuns.contains { run in
            run.count >= 8 && run.value.count <= 3
        }

        let words = splitWords(processedText)
        let mostCommonWord = mostCommonElement(in: words)
        let hasDictionaryWordDominance = words.count >= 30
            && dictionaryWords.contains(mostCommonWord.element)
            && Float(mostCommonWord.count) / Float(words.count) >= 0.34

        if hasDictionaryChunkFlood && (hasLowDiversitySpam || hasRunawayRepetition || hasDictionaryWordDominance) {
            return true
        }

        if dictionaryChunkRatio >= 0.35 && hasDictionaryRepeatedRun && hasShortNoiseRun {
            return true
        }

        return false
    }

    nonisolated private static func splitChunks(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map(normalizeForMatching(_:))
            .filter { !$0.isEmpty }
    }

    nonisolated private static func splitWords(_ text: String) -> [String] {
        normalizeForMatching(text)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    nonisolated private static func mostCommonCount(in elements: [String]) -> Int {
        mostCommonElement(in: elements).count
    }

    nonisolated private static func mostCommonElement(in elements: [String]) -> (element: String, count: Int) {
        guard !elements.isEmpty else { return ("", 0) }
        var counts: [String: Int] = [:]
        counts.reserveCapacity(elements.count)
        for element in elements {
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) } ?? ("", 0)
    }

    nonisolated private static func longestConsecutiveRun(in elements: [String]) -> Int {
        guard !elements.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        var previous = elements[0]
        for element in elements.dropFirst() {
            if element == previous {
                current += 1
                if current > longest {
                    longest = current
                }
            } else {
                previous = element
                current = 1
            }
        }
        return longest
    }

    nonisolated private static func consecutiveRuns(in elements: [String]) -> [(value: String, count: Int)] {
        guard !elements.isEmpty else { return [] }
        var runs: [(value: String, count: Int)] = []
        var currentValue = elements[0]
        var currentCount = 1
        for element in elements.dropFirst() {
            if element == currentValue {
                currentCount += 1
            } else {
                runs.append((value: currentValue, count: currentCount))
                currentValue = element
                currentCount = 1
            }
        }
        runs.append((value: currentValue, count: currentCount))
        return runs
    }

    nonisolated private static func normalizeForMatching(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\.\\s]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
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

@MainActor
class TranscriptionManager: ObservableObject {
    @Published var state: AppState = .idle
    @Published var lastTranscription: String = ""
    
    enum AppState: Equatable {
        case idle
        case recording
        case transcribing
        case error(String)
    }
    
    let keyboardMonitor = KeyboardMonitor.shared
    private let appSettings = AppSettingsStore.shared
    private let audioRecorder = AudioRecorder()
    private let whisperService = WhisperService()
    private let dictionaryStore = DictionaryStore.shared
    private let postProcessor = TranscriptionPostProcessor()
    private lazy var dictationPipeline = DictationPipeline(
        transcriptionProvider: whisperService,
        postProcessor: postProcessor,
        dictionaryEntriesProvider: { [weak self] in
            self?.dictionaryStore.entries ?? []
        },
        autoParagraphsEnabledProvider: { [weak self] in
            self?.appSettings.autoParagraphsEnabled ?? true
        },
        listRenderModeProvider: {
            PasteService.shared.preferredListRenderModeForFocusedElement()
        },
        recordSpokenWords: { [weak self] text in
            self?.appSettings.recordSpokenWords(from: text)
        },
        pasteText: { text in
            PasteService.shared.pasteText(text)
        }
    )
    private var isLocked = false
    private var cancellables = Set<AnyCancellable>()
    private let bluetoothStopSoundDelay: TimeInterval = 0.2
    private let defaultStopSoundDelay: TimeInterval = 0.0
    private let microphoneSilenceWarningDelay: TimeInterval = 0.5
    private let noSpeechWarningMinimumCaptureDuration = AudioSilenceGatePolicy.longTrueSilenceMinimumDuration
    
    init() {
        setupBindings()
        whisperService.warmup()
    }

    // Keep teardown executor-agnostic to avoid runtime deinit crashes in test host.
    nonisolated deinit {}
    
    private func setupBindings() {
        keyboardMonitor.$isTriggerKeyPressed
            .sink { [weak self] isPressed in
                self?.handleTriggerKey(isPressed: isPressed)
            }
            .store(in: &cancellables)
            
        keyboardMonitor.$escapePressedSignal
            .dropFirst()
            .sink { [weak self] _ in
                self?.abortRecording()
            }
            .store(in: &cancellables)

        dictionaryStore.$entries
            .sink { [weak self] _ in
                guard let self else { return }
                self.postProcessor.updateDictionaryEntries(self.dictionaryStore.entries)
                let hintPrompt = self.dictionaryStore.whisperHintPrompt()
                self.whisperService.updateDictionaryHintPrompt(hintPrompt)
            }
            .store(in: &cancellables)
    }
    
    private func abortRecording() {
        guard state == .recording || state == .transcribing else { return }
        
        #if DEBUG
        print("!! ESCAPE pressed: Aborting session !!")
        #endif
        
        playSound(named: "Bottle") // Cancel sound
        audioRecorder.stopRecording { _ in }
        whisperService.cancelTranscription()
        isLocked = false
        OverlayManager.shared.hide()
        state = .idle
    }
    
    private func handleTriggerKey(isPressed: Bool) {
        guard appSettings.hasCompletedOnboarding else { return }

        if isPressed {
            if state == .idle {
                startRecording()
            } else if state == .recording && isLocked {
                // If we are locked and press the key again, stop recording
                isLocked = false
                stopRecordingAndTranscribe()
            }
        } else {
            // Key released
            if state == .recording {
                if keyboardMonitor.isShiftPressed {
                    isLocked = true
                    #if DEBUG
                    print("Hands-free mode LOCKED")
                    #endif
                } else if !isLocked {
                    stopRecordingAndTranscribe()
                }
            }
        }
    }
    
    private func startRecording() {
        guard case .idle = state else { return }
        ModelDownloader.shared.refreshModelStatus()
        guard ModelDownloader.shared.isModelDownloaded else {
            OverlayManager.shared.hide()
            WarningManager.shared.show(.modelMissing)
            return
        }
        guard AXIsProcessTrusted() else {
            OverlayManager.shared.hide()
            WarningManager.shared.show(.accessibilityPermission)
            return
        }

        playSound(named: "Morse") // Start sound

        state = .recording
        WarningManager.shared.hide()
        OverlayManager.shared.show(recorder: audioRecorder)
        audioRecorder.startRecording()
    }
    
    private var stopRequestedAt: Date?
    
    private func stopRecordingAndTranscribe() {
        guard case .recording = state else { return }
        
        let startTime = Date()
        stopRequestedAt = startTime
        #if DEBUG
        print("--- Speed Profile Start ---")
        #endif
        
        isLocked = false

        audioRecorder.stopRecording { [weak self] frames in
            guard let self = self else { return }
            
            // Root Cause Fix: Bluetooth HFP/SCO to A2DP switching delay.
            // NSSound cannot play into a Bluetooth Voice channel (HFP).
            // We must wait for the hardware to renegotiate back to high-quality A2DP.
            let isBluetooth = self.audioRecorder.currentDeviceKind == .bluetooth || self.audioRecorder.currentDeviceKind == .airPods
            let delay: TimeInterval = isBluetooth ? self.bluetoothStopSoundDelay : self.defaultStopSoundDelay
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.playSound(named: "Frog") // Stop sound
            }

            let stopDuration = Date().timeIntervalSince(startTime)
            #if DEBUG
            print("1. Audio stop & buffer retrieve: \(String(format: "%.3f", stopDuration))s")
            #endif
            
            guard !frames.isEmpty else {
                OverlayManager.shared.hide()
                let microphoneName = self.audioRecorder.currentCaptureDeviceName
                let shouldShowNoSpeechWarning = self.audioRecorder.lastCaptureDuration >= self.noSpeechWarningMinimumCaptureDuration
                let showMicrophoneSilenceWarning: (WarningKind) -> Void = { kind in
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.microphoneSilenceWarningDelay) {
                        WarningManager.shared.show(kind)
                    }
                }
                if self.audioRecorder.lastCaptureWasLongTrueSilence {
                    showMicrophoneSilenceWarning(.microphoneSilence(
                        reason: .noSpeechDetected,
                        microphoneName: microphoneName
                    ))
                } else if self.audioRecorder.lastCaptureWasAbsoluteSilence {
                    showMicrophoneSilenceWarning(.microphoneSilence(
                        reason: .muted,
                        microphoneName: microphoneName
                    ))
                } else if self.audioRecorder.lastCaptureWasLikelySilence && shouldShowNoSpeechWarning {
                    showMicrophoneSilenceWarning(.microphoneSilence(
                        reason: .noSpeechDetected,
                        microphoneName: microphoneName
                    ))
                }
                self.state = .idle
                return
            }

            self.state = .transcribing
            
            // Transition overlay to transcription ripples only when we have frames to process.
            OverlayManager.shared.show(recorder: self.audioRecorder, isTranscribing: true)
            
            let useDictionaryHintPrompt = self.audioRecorder.lastCaptureHadActiveSignal
                && !self.audioRecorder.lastCaptureWasLikelySilence
                && !self.audioRecorder.lastCaptureWasLongTrueSilence
            self.dictationPipeline.run(
                audioFrames: frames,
                useDictionaryHintPrompt: useDictionaryHintPrompt
            ) { pipelineResult in
                let transcribeDuration = pipelineResult.inferenceDuration
                #if DEBUG
                print("2. Whisper inference: \(String(format: "%.3f", transcribeDuration))s")
                #endif
                
                DispatchQueue.main.async {
                    if pipelineResult.wasLikelyNoSpeech {
                        OverlayManager.shared.hide()
                        if self.audioRecorder.lastCaptureDuration >= self.noSpeechWarningMinimumCaptureDuration {
                            let warning = WarningKind.microphoneSilence(
                                reason: .noSpeechDetected,
                                microphoneName: self.audioRecorder.currentCaptureDeviceName
                            )
                            DispatchQueue.main.asyncAfter(deadline: .now() + self.microphoneSilenceWarningDelay) {
                                WarningManager.shared.show(warning)
                            }
                        }
                        self.state = .idle
                        return
                    }
                    self.lastTranscription = pipelineResult.finalText

                    let pasteDuration = pipelineResult.pasteDuration
                    #if DEBUG
                    print("3. Injection trigger: \(String(format: "%.3f", pasteDuration))s")
                    #endif
                    
                    let totalTime = Date().timeIntervalSince(startTime)
                    #if DEBUG
                    print("Total end-to-end latency: \(String(format: "%.3f", totalTime))s")
                    print("--- Speed Profile End ---")
                    #endif
                    
                    // Hide overlay only after transcription completes
                    OverlayManager.shared.hide()
                    self.state = .idle
                }
            }
        }
    }
    
    private func playSound(named name: String) {
        guard appSettings.isSoundEnabled else { return }
        if let sound = NSSound(named: name) {
            sound.volume = Float(appSettings.soundVolume)
            sound.play()
        }
    }
}
