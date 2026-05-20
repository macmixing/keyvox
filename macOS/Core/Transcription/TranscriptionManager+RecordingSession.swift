import ApplicationServices
import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

extension TranscriptionManager {
    var selectedRecordingVibeTitle: String? {
        let style = vibesCoordinator.selectedVibe
        guard style != .none else { return nil }
        return style.displayName
    }

    func cancelQuickTapRecording() {
        triggerController.cancelDeferredRecordingStart()
        let stopRequestID = UUID()
        stopRequestedAt = Date()
        activeStopRequestID = stopRequestID
        activeStopRequestPurpose = .quickTapCancellation
        state = .stopping
        isLocked = true

        audioRecorder.stopRecording { [weak self] _ in
            guard let self else { return }
            guard self.activeStopRequestID == stopRequestID else { return }
            Task { @MainActor [weak self] in
                await self?.vibesCoordinator.releasePrewarmSession(reason: "mac-quick-tap-cancel")
            }
            self.isLocked = false
            self.stopRequestedAt = nil
            self.activeStopRequestID = nil
            self.activeStopRequestPurpose = nil
            OverlayManager.shared.hide()
            self.state = .idle
            self.updateOverlayHandsFreeVisualState()
        }
    }

    func startRecording() {
        guard case .idle = state else { return }
        triggerController.cancelDeferredRecordingStart()
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

    func stopRecordingAndTranscribe() {
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
}
