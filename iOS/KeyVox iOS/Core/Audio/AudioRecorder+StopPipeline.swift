import Foundation
import KeyVoxCore
import AVFAudio

extension AudioRecorder {
    func stopRecording() async -> StoppedCapture {
        guard isRecording else {
            let idleCapture = makeStoppedCapture(
                snapshot: [],
                captureDuration: 0,
                maxActiveSignalRunDuration: 0
            )
            apply(stopResult: idleCapture, hadNonDeadSignal: false)
            return idleCapture
        }

        isRecording = false

        let snapshot = streamingState.snapshot()
        let captureDuration = Date().timeIntervalSince(captureStartedAt)
        let stoppedCapture = makeStoppedCapture(
            snapshot: snapshot.samples,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: snapshot.maxActiveSignalRunDuration
        )
        apply(stopResult: stoppedCapture, hadNonDeadSignal: snapshot.hadNonDeadSignal)

        // NOTE: We keep the engine running (isMonitoring remains true)
        // to maintain background persistence.
        return stoppedCapture
    }

    func cancelCurrentUtterance() {
        guard isRecording else { return }
        isRecording = false
        resetCurrentCaptureState()
        captureStartedAt = .distantPast
    }

    func handleActiveRecordingInterruption() {
        guard isRecording else { return }

        Self.log(
            "handleActiveRecordingInterruption routeInputs=\(String(audioSession.currentRoute.inputs.count)) engineRunning=\(String(audioEngine?.isRunning == true))"
        )

        let snapshot = streamingState.snapshot()
        let captureDuration = Date().timeIntervalSince(captureStartedAt)
        let interruptedCapture = makeStoppedCapture(
            snapshot: snapshot.samples,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: snapshot.maxActiveSignalRunDuration
        )

        invalidateAudioEngine(clearSessionActive: true)
        scheduleAudioSessionDeactivationForRouteRecovery()
        isRecording = false
        captureStartedAt = .distantPast
        apply(stopResult: interruptedCapture, hadNonDeadSignal: snapshot.hadNonDeadSignal)
        streamingState.reset()
        refreshCurrentCaptureDeviceName()
        audioInterruptedCaptureHandler?(interruptedCapture)
    }

    private func makeStoppedCapture(
        snapshot: [Float],
        captureDuration: TimeInterval,
        maxActiveSignalRunDuration: TimeInterval
    ) -> StoppedCapture {
        StoppedCaptureProcessor.process(
            snapshot: snapshot,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: maxActiveSignalRunDuration,
            gapRemovalRMSThreshold: sessionGapRemovalRMSThreshold,
            lowConfidenceRMSCutoff: sessionLikelySilenceRMSCutoff,
            trueSilenceWindowRMSThreshold: sessionTrueSilenceWindowRMSThreshold,
            normalizationTargetPeak: normalizationTargetPeak,
            normalizationMaxGain: normalizationMaxGain
        )
    }

    private func apply(stopResult: StoppedCapture, hadNonDeadSignal: Bool) {
        lastCaptureWasAbsoluteSilence = stopResult.classification.isAbsoluteSilence
        lastCaptureHadActiveSignal = stopResult.classification.hadActiveSignal
        lastCaptureWasLikelySilence = stopResult.classification.shouldRejectLikelySilence
        lastCaptureWasLongTrueSilence = stopResult.classification.isLongTrueSilence
        lastCaptureDuration = stopResult.captureDuration
        lastCaptureHadNonDeadSignal = hadNonDeadSignal
        maxActiveSignalRunDuration = stopResult.maxActiveSignalRunDuration
        audioLevel = 0
        liveInputSignalState = .dead
        liveMeterUpdateHandler?(0, .dead)
    }

    func resetCurrentCaptureState() {
        streamingState.reset()
        refreshCurrentCaptureDeviceName()
        lastCaptureWasAbsoluteSilence = false
        lastCaptureHadActiveSignal = false
        lastCaptureWasLikelySilence = false
        lastCaptureWasLongTrueSilence = false
        lastCaptureDuration = 0
        lastCaptureHadNonDeadSignal = false
        maxActiveSignalRunDuration = 0
        audioLevel = 0
        liveInputSignalState = .dead
        liveMeterUpdateHandler?(0, .dead)
    }
}
