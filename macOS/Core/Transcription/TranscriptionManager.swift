import SwiftUI
import Combine
import ApplicationServices
import KeyVoxCore
import KeyVoxStyleRewrite

@MainActor
class TranscriptionManager: ObservableObject {
    @Published var state: AppState = .idle
    @Published var lastTranscription: String = UserDefaults.standard.string(
        forKey: UserDefaultsKeys.App.lastTranscription
    ) ?? ""
    
    enum AppState: Equatable {
        case idle
        case recording
        case stopping
        case transcribing
        case error(String)
    }

    private enum StopRequestPurpose {
        case quickTapCancellation
        case transcription
    }
    
    let keyboardMonitor = KeyboardMonitor.shared
    private let appSettings: AppSettingsStore
    private let modelDownloader: ModelDownloader
    private let audioRecorder: AudioRecorder
    private let provider: any DictationProvider
    private let whisperService: WhisperService
    private let parakeetService: ParakeetService
    private let dictionaryStore: DictionaryStore
    private let weeklyWordStatsStore: WeeklyWordStatsStore
    private let postProcessor: TranscriptionPostProcessor
    private let vibesCoordinator: MacVibesCoordinator
    private lazy var dictationChangeController = MacDictationChangeController(
        vibesCoordinator: vibesCoordinator
    )
    private lazy var vibeTriggerActionController = MacVibesTriggerActionController(
        appSettings: appSettings,
        vibesCoordinator: vibesCoordinator,
        dictationChangeController: dictationChangeController
    )
    private lazy var dictationPipeline = DictationPipeline(
        transcriptionProvider: provider,
        postProcessor: postProcessor,
        dictionaryEntriesProvider: { [weak self] in
            self?.dictionaryStore.entries ?? []
        },
        autoParagraphsEnabledProvider: { [weak self] in
            self?.appSettings.autoParagraphsEnabled ?? true
        },
        listFormattingEnabledProvider: { [weak self] in
            self?.appSettings.listFormattingEnabled ?? true
        },
        capsLockEnabledProvider: { [weak self] in
            self?.cachedCapsLockIsOn ?? false
        },
        listRenderModeProvider: {
            PasteService.shared.preferredListRenderModeForFocusedElement()
        },
        recordSpokenWords: { [weak self] text in
            self?.weeklyWordStatsStore.recordSpokenWords(from: text)
        },
        pasteText: { text in
            PasteService.shared.pasteText(text)
        },
        processOutputText: { [weak self] text in
            guard let self else { return .unchanged(text) }
            return await self.vibesCoordinator.processOutputText(text)
        }
    )
    private var isLocked = false
    private var cachedCapsLockIsOn = false
    private var deferredRecordingStartWorkItem: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private let bluetoothStopSoundDelay: TimeInterval = 0.2
    private let defaultStopSoundDelay: TimeInterval = 0.0
    private let microphoneSilenceWarningDelay: TimeInterval = 0.5
    private let noSpeechWarningMinimumCaptureDuration = AudioSilenceGatePolicy.longTrueSilenceMinimumDuration
    private let dictionaryHintPromptMinimumCaptureDuration: TimeInterval = 0.45
    private let dictionaryHintPromptMinimumActiveSignalRunDuration: TimeInterval = 0.35
    
    convenience init() {
        self.init(
            appSettings: .shared,
            modelDownloader: .shared,
            audioRecorder: AudioRecorder(),
            serviceRegistry: .shared,
            vibesCoordinator: AppServiceRegistry.shared.vibesCoordinator,
            postProcessor: TranscriptionPostProcessor()
        )
    }

    init(
        appSettings: AppSettingsStore,
        modelDownloader: ModelDownloader,
        audioRecorder: AudioRecorder,
        serviceRegistry: AppServiceRegistry,
        vibesCoordinator: MacVibesCoordinator,
        postProcessor: TranscriptionPostProcessor
    ) {
        self.appSettings = appSettings
        self.modelDownloader = modelDownloader
        self.audioRecorder = audioRecorder
        self.provider = serviceRegistry.dictationProvider
        self.whisperService = serviceRegistry.whisperService
        self.parakeetService = serviceRegistry.parakeetService
        self.dictionaryStore = serviceRegistry.dictionaryStore
        self.weeklyWordStatsStore = serviceRegistry.weeklyWordStatsStore
        self.vibesCoordinator = vibesCoordinator
        self.postProcessor = postProcessor
        cachedCapsLockIsOn = keyboardMonitor.isCapsLockOn
        setupBindings()
        provider.warmup()
    }

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

    private func setupBindings() {
        keyboardMonitor.$triggerKeyEvent
            .compactMap { $0 }
            .sink { [weak self] event in
                self?.handleTriggerKey(
                    isPressed: event.isPressed,
                    timestamp: event.timestamp
                )
            }
            .store(in: &cancellables)

        keyboardMonitor.$isShiftPressed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateOverlayHandsFreeVisualState()
            }
            .store(in: &cancellables)
            
        keyboardMonitor.$escapePressedSignal
            .dropFirst()
            .sink { [weak self] _ in
                self?.abortRecording()
            }
            .store(in: &cancellables)

        keyboardMonitor.$isCapsLockOn
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isOn in
                self?.cachedCapsLockIsOn = isOn
            }
            .store(in: &cancellables)

        modelDownloader.$modelReady
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                guard let self else { return }
                if isReady {
                    self.whisperService.warmup()
                } else {
                    self.whisperService.unloadModel()
                }
            }
            .store(in: &cancellables)

        modelDownloader.$parakeetModelReady
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReady in
                guard let self else { return }
                if isReady {
                    self.parakeetService.warmup()
                } else {
                    self.parakeetService.unloadModel()
                }
            }
            .store(in: &cancellables)
    }
    
    private func abortRecording() {
        guard state == .recording || state == .stopping || state == .transcribing else { return }
        activeStopRequestID = nil
        stopRequestedAt = nil
        activeStopRequestPurpose = nil
        
        #if DEBUG
        print("!! ESCAPE pressed: Aborting session !!")
        #endif
        
        playSound(named: "Bottle") // Cancel sound
        cancelDeferredRecordingStart()
        vibeTriggerActionController.cancelPendingSingleTap()
        audioRecorder.stopRecording { _ in }
        provider.cancelTranscription()
        isLocked = false
        updateOverlayHandsFreeVisualState()
        OverlayManager.shared.hide()
        state = .idle
    }
    
    private func handleTriggerKey(isPressed: Bool, timestamp: TimeInterval) {
        guard appSettings.hasCompletedOnboarding else { return }
        guard stopRequestedAt == nil else {
            handleTriggerDuringPendingStop(isPressed: isPressed, timestamp: timestamp)
            updateOverlayHandsFreeVisualState()
            return
        }
        guard state != .stopping else {
            #if DEBUG
            if isPressed {
                print("Trigger ignored while session is transitioning from recording to transcription.")
            }
            #endif
            updateOverlayHandsFreeVisualState()
            return
        }

        if isPressed {
            if state == .idle {
                vibeTriggerActionController.noteTriggerPressed(at: timestamp)
                if vibeTriggerActionController.shouldSuppressRecordingStartForPotentialDoubleTap(at: timestamp) {
                    return
                }
                if vibeTriggerActionController.shouldDeferRecordingStartForVisibleCyclePill(
                    isCyclePillVisible: OverlayManager.shared.isVibeCyclePillVisible
                ) {
                    scheduleDeferredRecordingStart()
                    return
                }
                startRecording()
            } else if state == .recording && isLocked {
                vibeTriggerActionController.noteTriggerPressed(at: timestamp)
                // If we are locked and press the key again, stop recording
                isLocked = false
                stopRecordingAndTranscribe()
            } else if state != .recording {
                vibeTriggerActionController.clearTriggerPress()
            }
        } else {
            let didCancelDeferredRecordingStart = cancelDeferredRecordingStart()
            // Key released
            if state == .recording {
                if keyboardMonitor.isShiftPressed {
                    isLocked = true
                    #if DEBUG
                    print("Hands-free mode LOCKED")
                    #endif
                } else if !isLocked {
                    if vibeTriggerActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
                        cancelQuickTapRecording()
                        vibeTriggerActionController.handleQuickTap(at: timestamp)
                    } else {
                        stopRecordingAndTranscribe()
                    }
                }
            }
            if state == .idle,
               didCancelDeferredRecordingStart,
               vibeTriggerActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
                vibeTriggerActionController.handleQuickTap(at: timestamp)
            } else if state == .idle,
               vibeTriggerActionController.shouldSuppressRecordingStartForPotentialDoubleTap(at: timestamp),
               vibeTriggerActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
                vibeTriggerActionController.handleQuickTap(at: timestamp)
            }
            vibeTriggerActionController.clearTriggerPress()
        }

        updateOverlayHandsFreeVisualState()
    }

    private func handleTriggerDuringPendingStop(isPressed: Bool, timestamp: TimeInterval) {
        guard activeStopRequestPurpose == .quickTapCancellation else {
            vibeTriggerActionController.clearTriggerPress()
            return
        }

        if isPressed {
            cancelDeferredRecordingStart()
            vibeTriggerActionController.noteTriggerPressed(at: timestamp)
            return
        }

        cancelDeferredRecordingStart()
        if vibeTriggerActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
            vibeTriggerActionController.handleQuickTap(at: timestamp)
        }
        vibeTriggerActionController.clearTriggerPress()
    }

    private var selectedRecordingVibeTitle: String? {
        let style = vibesCoordinator.selectedVibe
        guard style != .none else { return nil }
        return style.displayName
    }

    private func cancelQuickTapRecording() {
        cancelDeferredRecordingStart()
        let stopRequestID = UUID()
        stopRequestedAt = Date()
        activeStopRequestID = stopRequestID
        activeStopRequestPurpose = .quickTapCancellation
        state = .stopping
        isLocked = true

        audioRecorder.stopRecording { [weak self] _ in
            guard let self else { return }
            guard self.activeStopRequestID == stopRequestID else { return }
            self.vibesCoordinator.releasePrewarmSession(reason: "mac-quick-tap-cancel")
            self.isLocked = false
            self.stopRequestedAt = nil
            self.activeStopRequestID = nil
            self.activeStopRequestPurpose = nil
            OverlayManager.shared.hide()
            self.state = .idle
            self.updateOverlayHandsFreeVisualState()
        }
    }

    private func startRecording() {
        guard case .idle = state else { return }
        cancelDeferredRecordingStart()
        modelDownloader.refreshModelStatus()
        guard provider.isModelReady else {
            OverlayManager.shared.hide()
            WarningManager.shared.show(.modelMissing)
            return
        }
        guard AXIsProcessTrusted() else {
            OverlayManager.shared.hide()
            WarningManager.shared.show(.accessibilityPermission)
            return
        }

        vibeTriggerActionController.cancelPendingSingleTap()
        playSound(named: "Morse") // Start sound

        state = .recording
        WarningManager.shared.hide()
        updateOverlayHandsFreeVisualState()
        OverlayManager.shared.show(
            recorder: audioRecorder,
            selectedVibeTitle: selectedRecordingVibeTitle
        )
        audioRecorder.startRecording()
        vibesCoordinator.prewarmForUpcomingDictationIfNeeded()
    }

    private func scheduleDeferredRecordingStart() {
        cancelDeferredRecordingStart()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.deferredRecordingStartWorkItem = nil
            guard self.state == .idle,
                  self.keyboardMonitor.isTriggerKeyPressed else {
                return
            }
            self.startRecording()
        }
        deferredRecordingStartWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + vibeTriggerActionController.quickTapDecisionDelay,
            execute: workItem
        )
    }

    @discardableResult
    private func cancelDeferredRecordingStart() -> Bool {
        let hadDeferredRecordingStart = deferredRecordingStartWorkItem != nil
        deferredRecordingStartWorkItem?.cancel()
        deferredRecordingStartWorkItem = nil
        return hadDeferredRecordingStart
    }

    private var stopRequestedAt: Date?
    private var activeStopRequestID: UUID?
    private var activeStopRequestPurpose: StopRequestPurpose?
    
    private func stopRecordingAndTranscribe() {
        guard case .recording = state else { return }
        guard activeStopRequestID == nil else { return }
        
        let startTime = Date()
        let stopRequestID = UUID()
        stopRequestedAt = startTime
        activeStopRequestID = stopRequestID
        activeStopRequestPurpose = .transcription
        state = .stopping
        #if DEBUG
        print("--- Speed Profile Start ---")
        #endif
        
        isLocked = false
        cachedCapsLockIsOn = keyboardMonitor.isCapsLockOn
        updateOverlayHandsFreeVisualState()

        audioRecorder.stopRecording { [weak self] frames in
            guard let self = self else { return }
            guard self.activeStopRequestID == stopRequestID else { return }
            self.activeStopRequestID = nil
            self.stopRequestedAt = nil
            self.activeStopRequestPurpose = nil
            
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

            if !self.audioRecorder.lastCaptureHadNonDeadSignal {
                OverlayManager.shared.hide()
                WarningManager.shared.show(.microphoneSilence(
                    reason: .muted,
                    microphoneName: self.audioRecorder.currentCaptureDeviceName
                ))
                self.state = .idle
                return
            }
            
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
            OverlayManager.shared.show(
                recorder: self.audioRecorder,
                isTranscribing: true,
                selectedVibeTitle: self.selectedRecordingVibeTitle
            )
            
            let useDictionaryHintPrompt = DictionaryHintPromptGate.shouldUseHintPrompt(
                lastCaptureHadActiveSignal: self.audioRecorder.lastCaptureHadActiveSignal,
                lastCaptureWasLikelySilence: self.audioRecorder.lastCaptureWasLikelySilence,
                lastCaptureWasLongTrueSilence: self.audioRecorder.lastCaptureWasLongTrueSilence,
                lastCaptureDuration: self.audioRecorder.lastCaptureDuration,
                maxActiveSignalRunDuration: self.audioRecorder.maxActiveSignalRunDuration,
                minimumCaptureDuration: self.dictionaryHintPromptMinimumCaptureDuration,
                minimumActiveSignalRunDuration: self.dictionaryHintPromptMinimumActiveSignalRunDuration
            )
            self.dictationPipeline.run(
                audioFrames: frames,
                useDictionaryHintPrompt: useDictionaryHintPrompt
            ) { pipelineResult in
                let transcribeDuration = pipelineResult.inferenceDuration
                #if DEBUG
                print("2. Provider inference: \(String(format: "%.3f", transcribeDuration))s")
                self.logTextTransformationSpeedProfile(pipelineResult)
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
                    UserDefaults.standard.set(
                        pipelineResult.finalText,
                        forKey: UserDefaultsKeys.App.lastTranscription
                    )
                    self.dictationChangeController.recordInsertedDictation(pipelineResult)

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

    private func updateOverlayHandsFreeVisualState() {
        let isPreviewActive = state == .recording &&
            stopRequestedAt == nil &&
            !isLocked &&
            keyboardMonitor.isTriggerKeyPressed &&
            keyboardMonitor.isShiftPressed
        OverlayManager.shared.setHandsFreeLocked(isLocked)
        OverlayManager.shared.setHandsFreeModifierPreviewActive(isPreviewActive)
    }
    
    private func playSound(named name: String) {
        guard appSettings.isSoundEnabled else { return }
        if let sound = NSSound(named: name) {
            sound.volume = Float(appSettings.soundVolume)
            sound.play()
        }
    }

    #if DEBUG
    private func logTextTransformationSpeedProfile(_ result: DictationPipelineResult) {
        let duration = String(format: "%.3f", result.textTransformationDuration)
        let style = result.textTransformationStyleIdentifier ?? "none"
        let mode = result.textTransformationProcessingMode.map { " mode=\($0)" } ?? ""
        let chunkSummary = " style=\(style)\(mode) chunks=\(result.textTransformationChunkCount)"
        let finalTextSuffix = " finalText=\(escapedDebugText(result.finalText))"
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

    private func escapedDebugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
    }
    #endif
}
