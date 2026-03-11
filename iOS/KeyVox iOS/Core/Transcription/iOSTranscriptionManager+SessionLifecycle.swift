import Foundation

extension iOSTranscriptionManager {
    func handleRecorderInterruptedCapture(_ stoppedCapture: iOSStoppedCapture) async {
        guard state == .recording else { return }

        let utteranceID = activeUtteranceID
        cancelUtteranceSafetyWatchdog()
        state = .processingCapture
        isSessionActive = recorder.isMonitoring
        sessionDisablePending = false
        cancelIdleTimeout()
        lastErrorMessage = nil

        await completeStopRecording(
            stoppedCapture,
            utteranceID: utteranceID,
            startTime: Date()
        )
    }

    func armIdleTimeout() {
        cancelIdleTimeout()

        guard isSessionActive,
              !sessionDisablePending,
              let idleTimeout = sessionPolicy.idleTimeout else {
            return
        }

        let expirationDate = Date().addingTimeInterval(idleTimeout)
        sessionExpirationDate = expirationDate
        idleTimeoutTask = Task { [weak self] in
            let duration = UInt64(idleTimeout * 1_000_000_000)
            try? await Task.sleep(nanoseconds: duration)
            await self?.handleIdleTimeoutFired()
        }
    }

    func cancelIdleTimeout() {
        idleTimeoutTask?.cancel()
        idleTimeoutTask = nil
        sessionExpirationDate = nil
    }

    func armUtteranceSafetyWatchdog(for utteranceID: UUID) {
        cancelUtteranceSafetyWatchdog()

        let configuredThresholds = [
            sessionPolicy.noSpeechAbandonmentTimeout,
            sessionPolicy.postSpeechInactivityTimeout,
            sessionPolicy.emergencyUtteranceCap
        ].compactMap { $0 }
        let minimumThreshold = configuredThresholds.min() ?? 1
        let checkInterval = max(0.05, min(1.0, minimumThreshold / 4))

        utteranceSafetyTask = Task { [weak self] in
            while let self, !Task.isCancelled {
                let sleepDuration = UInt64(checkInterval * 1_000_000_000)
                try? await Task.sleep(nanoseconds: sleepDuration)
                guard await self.shouldCancelUtteranceForSafety(utteranceID: utteranceID) else { continue }
                await self.performCancelCurrentUtterance()
                return
            }
        }
    }

    func cancelUtteranceSafetyWatchdog() {
        utteranceSafetyTask?.cancel()
        utteranceSafetyTask = nil
    }

    func handleIdleTimeoutFired() async {
        guard isSessionActive, !sessionDisablePending, state == .idle else { return }
        await completeSessionShutdown()
    }

    func finishAndDisableSessionIfNeeded() async {
        if sessionDisablePending && state == .idle {
            await completeSessionShutdown()
        } else if isSessionActive && state == .idle {
            armIdleTimeout()
        }
    }

    func completeSessionShutdown() async {
        cancelIdleTimeout()
        cancelUtteranceSafetyWatchdog()

        do {
            try recorder.stopMonitoring()
            isSessionActive = false
            sessionDisablePending = false
            sessionExpirationDate = nil
            keyboardBridge.publishCancelled()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func performCancelCurrentUtterance() async {
        guard state != .idle else { return }

        let shouldShutdownAfterCancel = sessionDisablePending
        activeUtteranceID = UUID()
        cancelUtteranceSafetyWatchdog()
        pendingPipelineOutputText = nil
        lastTranscriptionSnapshot = nil
        lastErrorMessage = nil

        switch state {
        case .recording:
            recorder.cancelCurrentUtterance()
        case .processingCapture, .transcribing:
            transcriptionService.cancelTranscription()
        case .idle:
            break
        }

        state = .idle
        keyboardBridge.publishCancelled()

        if shouldShutdownAfterCancel {
            await completeSessionShutdown()
        } else {
            await finishAndDisableSessionIfNeeded()
        }
    }

    func shouldCancelUtteranceForSafety(utteranceID: UUID) async -> Bool {
        guard activeUtteranceID == utteranceID, state == .recording else { return false }

        let duration = recorder.currentCaptureDuration
        if let emergencyUtteranceCap = sessionPolicy.emergencyUtteranceCap,
           duration >= emergencyUtteranceCap {
            return true
        }

        if !recorder.hasMeaningfulSpeechInCurrentCapture,
           let noSpeechAbandonmentTimeout = sessionPolicy.noSpeechAbandonmentTimeout,
           duration >= noSpeechAbandonmentTimeout {
            return true
        }

        if recorder.hasMeaningfulSpeechInCurrentCapture,
           let inactivity = recorder.timeSinceLastMeaningfulSpeech,
           let postSpeechInactivityTimeout = sessionPolicy.postSpeechInactivityTimeout,
           inactivity >= postSpeechInactivityTimeout {
            return true
        }

        return false
    }
}
