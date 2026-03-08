import AVFoundation
import Foundation
import KeyVoxCore

extension iOSAudioRecorder {
    func enableMonitoring() async throws {
        let permissionGranted = await requestRecordPermission()
        guard permissionGranted else {
            throw iOSAudioRecorderError.microphonePermissionDenied
        }

        try ensureEngineRunning()
    }

    func ensureEngineRunning() throws {
        guard !isMonitoring || audioEngine == nil || !audioEngine!.isRunning else { return }

        // Set up audio session for background persistence
        try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP])
        try audioSession.setPreferredSampleRate(outputFormat.sampleRate)
        try audioSession.setActive(true)

        let engine = audioEngine ?? AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        let bufferSize: AVAudioFrameCount = 1024
        
        // Capture properties for closure
        let streamingState = self.streamingState
        let outputFormat = self.outputFormat
        let deadSignalPeakThreshold = self.deadSignalPeakThreshold
        let sessionActiveSignalRMSThreshold = self.sessionActiveSignalRMSThreshold
        let visualActiveSignalThresholdMultiplier = self.visualActiveSignalThresholdMultiplier
        let deadStateHoldDuration = self.deadStateHoldDuration
        let visualActiveStateHoldDuration = self.visualActiveStateHoldDuration

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self, streamingState, outputFormat, deadSignalPeakThreshold, sessionActiveSignalRMSThreshold, visualActiveSignalThresholdMultiplier, deadStateHoldDuration, visualActiveStateHoldDuration] buffer, _ in
            guard let self else { return }
            
            // Heartbeat for IPC bridge
            self.heartbeatCallback?()
            
            // Only process audio for transcription if we are actually recording
            guard self.isRecording else { return }

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
            Task { @MainActor in
                self.audioLevel = update.level
                self.liveInputSignalState = update.signalState
            }
        }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        
        audioEngine = engine
        isMonitoring = true
        
        // Mark session as warm now that engine is running
        KeyVoxIPCBridge.setSessionActive()
    }

    func stopMonitoring() throws {
        guard isMonitoring else { return }
        guard !isRecording else {
            throw iOSAudioRecorderError.monitoringShutdownWhileRecording
        }

        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil

        do {
            try audioSession.setActive(false)
        } catch {
            throw iOSAudioRecorderError.engineStopFailed(underlying: error)
        }

        isMonitoring = false
        audioLevel = 0
        liveInputSignalState = .dead
        KeyVoxIPCBridge.clearSessionActive()
    }

    func startRecording() async throws {
        guard !isRecording else { return }

        let permissionGranted = await requestRecordPermission()
        guard permissionGranted else {
            throw iOSAudioRecorderError.microphonePermissionDenied
        }

        // Ensure engine is running (in monitor mode)
        try ensureEngineRunning()

        // Reset state for new capture
        resetCurrentCaptureState()
        captureStartedAt = Date()
        isRecording = true
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

        // NOTE: We keep the engine running (isMonitoring remains true)
        // to maintain background persistence.

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

    func cancelCurrentUtterance() {
        guard isRecording else { return }
        isRecording = false
        resetCurrentCaptureState()
        captureStartedAt = .distantPast
    }

    private func resetCurrentCaptureState() {
        streamingState.reset()
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
    case engineStopFailed(underlying: Error)
    case monitoringShutdownWhileRecording

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required to start recording."
        case let .engineStartFailed(underlying):
            return "Couldn't start audio capture: \(underlying.localizedDescription)"
        case let .engineStopFailed(underlying):
            return "Couldn't stop audio capture: \(underlying.localizedDescription)"
        case .monitoringShutdownWhileRecording:
            return "Can't disable the session while audio is actively recording."
        }
    }
}
