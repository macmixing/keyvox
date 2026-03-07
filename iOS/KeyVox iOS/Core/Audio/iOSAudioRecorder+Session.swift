import AVFoundation
import Foundation
import KeyVoxCore

extension iOSAudioRecorder {
    func startRecording() async throws {
        guard !isRecording else { return }

        let permissionGranted = await requestRecordPermission()
        guard permissionGranted else {
            throw iOSAudioRecorderError.microphonePermissionDenied
        }

        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try audioSession.setPreferredSampleRate(outputFormat.sampleRate)
        try audioSession.setActive(true)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 1024
        let streamingState = self.streamingState
        let outputFormat = self.outputFormat
        let deadSignalPeakThreshold = self.deadSignalPeakThreshold
        let sessionActiveSignalRMSThreshold = self.sessionActiveSignalRMSThreshold
        let visualActiveSignalThresholdMultiplier = self.visualActiveSignalThresholdMultiplier
        let deadStateHoldDuration = self.deadStateHoldDuration
        let visualActiveStateHoldDuration = self.visualActiveStateHoldDuration

        streamingState.reset()
        captureStartedAt = Date()
        currentCaptureDeviceName = AudioSilenceGatePolicy.normalizedMicrophoneName("iPhone Microphone")
        lastCaptureWasAbsoluteSilence = false
        lastCaptureHadActiveSignal = false
        lastCaptureWasLikelySilence = false
        lastCaptureWasLongTrueSilence = false
        lastCaptureDuration = 0
        lastCaptureHadNonDeadSignal = false
        maxActiveSignalRunDuration = 0
        audioLevel = 0
        liveInputSignalState = .dead

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self, streamingState, outputFormat, deadSignalPeakThreshold, sessionActiveSignalRMSThreshold, visualActiveSignalThresholdMultiplier, deadStateHoldDuration, visualActiveStateHoldDuration] buffer, _ in
            let update = streamingState.process(
                inputBuffer: buffer,
                outputFormat: outputFormat,
                deadSignalPeakThreshold: deadSignalPeakThreshold,
                activeSignalRMSThreshold: sessionActiveSignalRMSThreshold,
                visualActiveSignalThresholdMultiplier: visualActiveSignalThresholdMultiplier,
                deadStateHoldDuration: deadStateHoldDuration,
                visualActiveStateHoldDuration: visualActiveStateHoldDuration
            )

            guard let update else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.audioLevel = update.level
                self.liveInputSignalState = update.signalState
            }
        }

        do {
            engine.prepare()
            try engine.start()
            audioEngine = engine
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            try? audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
            throw iOSAudioRecorderError.engineStartFailed(underlying: error)
        }
    }

    func stopRecording() async -> iOSStoppedCapture {
        guard isRecording else {
            let idleCapture = iOSStoppedCaptureProcessor.process(
                snapshot: [],
                captureDuration: 0,
                maxActiveSignalRunDuration: 0,
                gapRemovalRMSThreshold: sessionGapRemovalRMSThreshold,
                lowConfidenceRMSCutoff: sessionLikelySilenceRMSCutoff,
                trueSilenceWindowRMSThreshold: sessionTrueSilenceWindowRMSThreshold,
                normalizationTargetPeak: normalizationTargetPeak,
                normalizationMaxGain: normalizationMaxGain
            )
            apply(stopResult: idleCapture, hadNonDeadSignal: false)
            return idleCapture
        }

        let engine = audioEngine
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        audioEngine = nil
        isRecording = false

        let snapshot = streamingState.snapshot()
        let captureDuration = Date().timeIntervalSince(captureStartedAt)
        let stoppedCapture = iOSStoppedCaptureProcessor.process(
            snapshot: snapshot.samples,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: snapshot.maxActiveSignalRunDuration,
            gapRemovalRMSThreshold: sessionGapRemovalRMSThreshold,
            lowConfidenceRMSCutoff: sessionLikelySilenceRMSCutoff,
            trueSilenceWindowRMSThreshold: sessionTrueSilenceWindowRMSThreshold,
            normalizationTargetPeak: normalizationTargetPeak,
            normalizationMaxGain: normalizationMaxGain
        )
        apply(stopResult: stoppedCapture, hadNonDeadSignal: snapshot.hadNonDeadSignal)

        do {
            try audioSession.setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            #if DEBUG
            print("Failed to deactivate AVAudioSession: \(error)")
            #endif
        }

        return stoppedCapture
    }

    private func apply(stopResult: iOSStoppedCapture, hadNonDeadSignal: Bool) {
        lastCaptureWasAbsoluteSilence = stopResult.classification.isAbsoluteSilence
        lastCaptureHadActiveSignal = stopResult.classification.hadActiveSignal
        lastCaptureWasLikelySilence = stopResult.classification.shouldRejectLikelySilence
        lastCaptureWasLongTrueSilence = stopResult.classification.isLongTrueSilence
        lastCaptureDuration = stopResult.captureDuration
        lastCaptureHadNonDeadSignal = hadNonDeadSignal
        maxActiveSignalRunDuration = stopResult.maxActiveSignalRunDuration
        audioLevel = 0
        liveInputSignalState = .dead
    }

    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

enum iOSAudioRecorderError: LocalizedError {
    case microphonePermissionDenied
    case engineStartFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to start recording."
        case let .engineStartFailed(underlying):
            return "Couldn't start audio capture: \(underlying.localizedDescription)"
        }
    }
}
