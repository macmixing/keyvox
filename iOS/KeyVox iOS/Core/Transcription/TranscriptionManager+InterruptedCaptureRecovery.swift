import Foundation
import KeyVoxCore

extension TranscriptionManager {
    func handleAppDidBecomeActive() {
        Task { await resumeInterruptedCaptureRecoveryIfNeeded() }
    }

    func handleRecorderSessionInterrupted() async {
        cancelIdleTimeout()
        cancelUtteranceSafetyWatchdog()
        pendingPipelineOutputText = nil
        state = .idle
        isSessionActive = recorder.isMonitoring
        sessionDisablePending = false
        sessionExpirationDate = nil
        keyboardBridge.publishCancelled()
    }

    func stageInterruptedCaptureIfNeeded(_ stoppedCapture: StoppedCapture) {
        guard let payload = interruptedCaptureRecoveryPayload(for: stoppedCapture) else {
            setInterruptedCaptureRecoveryPresence(interruptedCaptureRecoveryStore.load() != nil)
            return
        }

        do {
            try interruptedCaptureRecoveryStore.save(payload)
            setInterruptedCaptureRecoveryPresence(true)
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func resumeInterruptedCaptureRecoveryIfNeeded() async {
        guard state == .idle else { return }

        refreshModelAvailability()
        guard isModelAvailable else { return }

        guard var payload = interruptedCaptureRecoveryStore.load() else {
            setInterruptedCaptureRecoveryPresence(false)
            isRecoveringInterruptedCapture = false
            return
        }

        switch payload.recovery.status {
        case .pending:
            break
        case .transcribing:
            payload.recovery.status = .pending
            payload.recovery.failureReason = nil
        case .failed:
            setInterruptedCaptureRecoveryPresence(true)
            return
        }

        payload.recovery.status = .transcribing
        payload.recovery.failureReason = nil

        do {
            try interruptedCaptureRecoveryStore.save(payload)
            setInterruptedCaptureRecoveryPresence(true)
        } catch {
            isRecoveringInterruptedCapture = false
            lastErrorMessage = error.localizedDescription
            return
        }

        pendingPipelineOutputText = nil
        lastErrorMessage = nil
        isRecoveringInterruptedCapture = true
        state = .transcribing
        transcriptionService.warmup()

        dictationPipeline.run(
            audioFrames: payload.audioFrames,
            useDictionaryHintPrompt: payload.recovery.usedDictionaryHintPrompt
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }

                let finalText = self.pendingPipelineOutputText ?? result.finalText
                self.pendingPipelineOutputText = nil
                self.state = .idle

                if result.wasLikelyNoSpeech {
                    self.clearInterruptedCaptureRecovery()
                    return
                }

                let trimmedText = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedText.isEmpty else {
                    self.markInterruptedCaptureRecoveryFailed("Interrupted capture recovery produced no transcription.")
                    return
                }

                self.lastErrorMessage = nil
                self.lastTranscriptionText = finalText
                KeyVoxIPCBridge.setTranscription(finalText)
                self.clearInterruptedCaptureRecovery()
            }
        }
    }

    private func interruptedCaptureRecoveryPayload(for stoppedCapture: StoppedCapture) -> InterruptedCaptureRecoveryPayload? {
        guard !stoppedCapture.outputFrames.isEmpty else { return nil }

        let usedDictionaryHintPrompt = !dictionaryStore.entries.isEmpty && DictionaryHintPromptGate.shouldUseHintPrompt(
            lastCaptureHadActiveSignal: recorder.lastCaptureHadActiveSignal,
            lastCaptureWasLikelySilence: recorder.lastCaptureWasLikelySilence,
            lastCaptureWasLongTrueSilence: recorder.lastCaptureWasLongTrueSilence,
            lastCaptureDuration: recorder.lastCaptureDuration,
            maxActiveSignalRunDuration: recorder.maxActiveSignalRunDuration
        )

        return InterruptedCaptureRecoveryPayload(
            recovery: InterruptedCaptureRecovery(
                capturedAt: Date(),
                captureDuration: stoppedCapture.captureDuration,
                maxActiveSignalRunDuration: stoppedCapture.maxActiveSignalRunDuration,
                usedDictionaryHintPrompt: usedDictionaryHintPrompt,
                audioFrameCount: stoppedCapture.outputFrames.count,
                status: .pending,
                failureReason: nil
            ),
            audioFrames: stoppedCapture.outputFrames
        )
    }

    private func clearInterruptedCaptureRecovery() {
        do {
            try interruptedCaptureRecoveryStore.clear()
            setInterruptedCaptureRecoveryPresence(false)
            isRecoveringInterruptedCapture = false
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    private func markInterruptedCaptureRecoveryFailed(_ reason: String) {
        guard var payload = interruptedCaptureRecoveryStore.load() else {
            setInterruptedCaptureRecoveryPresence(false)
            return
        }

        payload.recovery.status = .failed
        payload.recovery.failureReason = reason

        do {
            try interruptedCaptureRecoveryStore.save(payload)
            setInterruptedCaptureRecoveryPresence(true)
            isRecoveringInterruptedCapture = false
            lastErrorMessage = reason
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }
}
