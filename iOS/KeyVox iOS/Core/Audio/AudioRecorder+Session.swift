import AVFoundation
import Foundation
import KeyVoxCore

struct AudioInputPreferenceResolver {
    struct Candidate {
        let id: String
        let portType: AVAudioSession.Port
    }

    enum Action {
        case preferInput(id: String)
        case useSystemDefault
        case keepCurrentRoute
    }

    func resolve(
        availableInputs: [Candidate],
        preferBuiltInMicrophone: Bool
    ) -> Action {
        guard preferBuiltInMicrophone else {
            return .useSystemDefault
        }

        guard let builtInMicrophone = availableInputs.first(where: { $0.portType == .builtInMic }) else {
            return .keepCurrentRoute
        }

        return .preferInput(id: builtInMicrophone.id)
    }
}

extension AudioRecorder {
    func configureAudioSessionInterruptionObserver() {
        guard audioSessionInterruptionObserver == nil else { return }

        audioSessionInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: audioSession,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                self?.handleAudioSessionInterruption(notification)
            }
        }
    }

    func removeAudioSessionInterruptionObserver() {
        guard let audioSessionInterruptionObserver else { return }
        NotificationCenter.default.removeObserver(audioSessionInterruptionObserver)
        self.audioSessionInterruptionObserver = nil
    }

    func configureEngineConfigurationObserver() {
        guard engineConfigurationObserver == nil else { return }

        engineConfigurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated {
                guard let self else { return }
                guard notification.object as AnyObject? === self.audioEngine else { return }
                self.handleEngineConfigurationChange()
            }
        }
    }

    func removeEngineConfigurationObserver() {
        guard let engineConfigurationObserver else { return }
        NotificationCenter.default.removeObserver(engineConfigurationObserver)
        self.engineConfigurationObserver = nil
    }

    func enableMonitoring() async throws {
        let permissionGranted = await requestRecordPermission()
        guard permissionGranted else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        try ensureEngineRunning()
    }

    func repairMonitoringAfterPlayback() async throws {
        let permissionGranted = await requestRecordPermission()
        guard permissionGranted else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let recoveryDelays: [UInt64] = [
            0,
            350_000_000,
            750_000_000,
            1_250_000_000
        ]
        var lastError: Error?

        for (attemptIndex, delay) in recoveryDelays.enumerated() {
            if delay > 0 {
                invalidateAudioEngine(clearSessionActive: true)
                deactivateAudioSessionForRouteRecovery()
                try? await Task.sleep(nanoseconds: delay)
                refreshCurrentCaptureDeviceName()
            }

            do {
                try ensureEngineRunning()
                lastError = nil
                break
            } catch {
                lastError = error
                NSLog(
                    "[AudioRecorder] repairMonitoring attempt=%@ failed error=%@ retryable=%@",
                    String(attemptIndex + 1),
                    error.localizedDescription,
                    String(shouldRetryRecordingStartAfterRouteTransition(for: error))
                )
                guard shouldRetryRecordingStartAfterRouteTransition(for: error),
                      attemptIndex < recoveryDelays.count - 1 else {
                    throw error
                }
            }
        }

        if let lastError {
            throw lastError
        }
    }

    func ensureEngineRunning() throws {
        guard !isMonitoring || audioEngine == nil || !audioEngine!.isRunning else { return }

        let routeInputPorts = audioSession.currentRoute.inputs
            .map { $0.portType.rawValue }
            .joined(separator: ",")
        let routeOutputPorts = audioSession.currentRoute.outputs
            .map { $0.portType.rawValue }
            .joined(separator: ",")

        NSLog(
            "[AudioRecorder] ensureEngineRunning begin isMonitoring=%@ engineExists=%@ engineRunning=%@ routeInputs=%@ routeOutputs=%@ category=%@ mode=%@ otherAudioPlaying=%@",
            String(isMonitoring),
            String(audioEngine != nil),
            String(audioEngine?.isRunning == true),
            routeInputPorts,
            routeOutputPorts,
            audioSession.category.rawValue,
            audioSession.mode.rawValue,
            String(audioSession.isOtherAudioPlaying)
        )

        // Set up audio session for background persistence
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothHFP])
            NSLog("[AudioRecorder] setCategory(playAndRecord) succeeded")
        } catch {
            NSLog("[AudioRecorder] setCategory(playAndRecord) failed error=%@", error.localizedDescription)
            throw error
        }

        do {
            try audioSession.setAllowHapticsAndSystemSoundsDuringRecording(true)
            NSLog("[AudioRecorder] setAllowHapticsAndSystemSoundsDuringRecording(true) succeeded")
        } catch {
            NSLog("[AudioRecorder] setAllowHapticsAndSystemSoundsDuringRecording(true) failed error=%@", error.localizedDescription)
            throw error
        }
        // Keep the hardware route's native sample rate. Bluetooth HFP routes can reject
        // a forced 16 kHz preference, and we already convert captured audio into the
        // recorder's 16 kHz output format downstream.
        do {
            try audioSession.setActive(true)
            let activeRouteInputPorts = audioSession.currentRoute.inputs
                .map { $0.portType.rawValue }
                .joined(separator: ",")
            let activeRouteOutputPorts = audioSession.currentRoute.outputs
                .map { $0.portType.rawValue }
                .joined(separator: ",")
            NSLog(
                "[AudioRecorder] setActive(true) succeeded routeInputs=%@ routeOutputs=%@ sampleRate=%@",
                activeRouteInputPorts,
                activeRouteOutputPorts,
                String(audioSession.sampleRate)
            )
        } catch {
            NSLog("[AudioRecorder] setActive(true) failed error=%@", error.localizedDescription)
            throw error
        }

        do {
            try applyInputPreference()
            NSLog(
                "[AudioRecorder] applyInputPreference succeeded currentInput=%@ preferredInput=%@",
                String(describing: audioSession.currentRoute.inputs.first?.portType.rawValue),
                String(describing: audioSession.preferredInput?.portType.rawValue)
            )
        } catch {
            NSLog("[AudioRecorder] applyInputPreference failed error=%@", error.localizedDescription)
            throw error
        }

        // Route changes can leave a stopped engine bound to a stale hardware format.
        // Always rebuild from a fresh engine when we need to restart monitoring.
        invalidateAudioEngine(clearSessionActive: false)

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        // Smaller buffers give the keyboard logo a denser stream of level updates
        // so the shared waveform feels closer to the Mac overlay.
        let bufferSize: AVAudioFrameCount = 512
        
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
                self.liveMeterUpdateHandler?(update.level, update.signalState)
            }
        }

        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
        
        audioEngine = engine
        isMonitoring = true
        refreshCurrentCaptureDeviceName()

        // Mark session as warm now that engine is running
        KeyVoxIPCBridge.setSessionActive()
    }

    func stopMonitoring() throws {
        guard isMonitoring else { return }
        guard !isRecording else {
            throw AudioRecorderError.monitoringShutdownWhileRecording
        }

        invalidateAudioEngine(clearSessionActive: false)

        do {
            try audioSession.setActive(false)
        } catch {
            throw AudioRecorderError.engineStopFailed(underlying: error)
        }

        isMonitoring = false
        audioLevel = 0
        liveInputSignalState = .dead
        liveMeterUpdateHandler?(0, .dead)
        KeyVoxIPCBridge.clearSessionActive()
    }

    func startRecording() async throws {
        guard !isRecording else { return }

        let permissionGranted = await requestRecordPermission()
        guard permissionGranted else {
            throw AudioRecorderError.microphonePermissionDenied
        }

        let recoveryDelays: [UInt64] = [
            0,
            350_000_000,
            750_000_000,
            1_250_000_000
        ]
        var lastError: Error?

        for (attemptIndex, delay) in recoveryDelays.enumerated() {
            if delay > 0 {
                invalidateAudioEngine(clearSessionActive: true)
                deactivateAudioSessionForRouteRecovery()
                try await Task.sleep(nanoseconds: delay)
                refreshCurrentCaptureDeviceName()
            }

            do {
                try ensureEngineRunning()
                try applyInputPreference()
                lastError = nil
                break
            } catch {
                lastError = error
                NSLog(
                    "[AudioRecorder] startRecording attempt=%@ failed error=%@ retryable=%@",
                    String(attemptIndex + 1),
                    error.localizedDescription,
                    String(shouldRetryRecordingStartAfterRouteTransition(for: error))
                )
                guard shouldRetryRecordingStartAfterRouteTransition(for: error),
                      attemptIndex < recoveryDelays.count - 1 else {
                    throw error
                }
            }
        }

        if let lastError {
            throw lastError
        }

        // Reset state for new capture
        resetCurrentCaptureState()
        captureStartedAt = Date()
        isRecording = true
    }

    func stopRecording() async -> StoppedCapture {
        guard isRecording else {
            let idleCapture = StoppedCaptureProcessor.process(
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
        let stoppedCapture = StoppedCaptureProcessor.process(
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

    func cancelCurrentUtterance() {
        guard isRecording else { return }
        isRecording = false
        resetCurrentCaptureState()
        captureStartedAt = .distantPast
    }

    private func resetCurrentCaptureState() {
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

    private func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func invalidateAudioEngine(clearSessionActive: Bool) {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine?.reset()
        audioEngine = nil
        isMonitoring = false
        audioLevel = 0
        liveInputSignalState = .dead
        liveMeterUpdateHandler?(0, .dead)

        if clearSessionActive {
            KeyVoxIPCBridge.clearSessionActive()
        }
    }

    private func handleEngineConfigurationChange() {
        guard isRecording else { return }
        guard audioEngine?.isRunning != true else { return }

        handleActiveRecordingInterruption()
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let rawType = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }

        NSLog(
            "[AudioRecorder] audioSessionInterruption type=%@ isRecording=%@ isMonitoring=%@",
            String(describing: interruptionType.rawValue),
            String(isRecording),
            String(isMonitoring)
        )

        switch interruptionType {
        case .began:
            if isRecording {
                handleActiveRecordingInterruption()
            } else if isMonitoring {
                handleMonitoringInterruption()
            }
        case .ended:
            refreshCurrentCaptureDeviceName()
        @unknown default:
            break
        }
    }

    private func handleMonitoringInterruption() {
        NSLog(
            "[AudioRecorder] handleMonitoringInterruption routeInputs=%@ engineRunning=%@",
            String(audioSession.currentRoute.inputs.count),
            String(audioEngine?.isRunning == true)
        )
        invalidateAudioEngine(clearSessionActive: true)
        deactivateAudioSessionForRouteRecovery()
        refreshCurrentCaptureDeviceName()
        audioSessionInterruptedHandler?()
    }

    private func handleActiveRecordingInterruption() {
        guard isRecording else { return }

        NSLog(
            "[AudioRecorder] handleActiveRecordingInterruption routeInputs=%@ engineRunning=%@",
            String(audioSession.currentRoute.inputs.count),
            String(audioEngine?.isRunning == true)
        )

        let snapshot = streamingState.snapshot()
        let captureDuration = Date().timeIntervalSince(captureStartedAt)
        let interruptedCapture = StoppedCaptureProcessor.process(
            snapshot: snapshot.samples,
            captureDuration: captureDuration,
            maxActiveSignalRunDuration: snapshot.maxActiveSignalRunDuration,
            gapRemovalRMSThreshold: sessionGapRemovalRMSThreshold,
            lowConfidenceRMSCutoff: sessionLikelySilenceRMSCutoff,
            trueSilenceWindowRMSThreshold: sessionTrueSilenceWindowRMSThreshold,
            normalizationTargetPeak: normalizationTargetPeak,
            normalizationMaxGain: normalizationMaxGain
        )

        invalidateAudioEngine(clearSessionActive: true)
        deactivateAudioSessionForRouteRecovery()
        isRecording = false
        captureStartedAt = .distantPast
        apply(stopResult: interruptedCapture, hadNonDeadSignal: snapshot.hadNonDeadSignal)
        streamingState.reset()
        refreshCurrentCaptureDeviceName()
        audioInterruptedCaptureHandler?(interruptedCapture)
    }

    private func deactivateAudioSessionForRouteRecovery() {
        // The session may already be transitioning during a route change, but recovery
        // should continue with a fresh engine either way.
        NSLog("[AudioRecorder] deactivateAudioSessionForRouteRecovery")
        try? audioSession.setActive(false)
    }

    private func shouldRetryRecordingStartAfterRouteTransition(for error: Error) -> Bool {
        let nsError = error as NSError
        let hasNoInputs = audioSession.currentRoute.inputs.isEmpty
        let isBluetoothA2DPOnly = audioSession.currentRoute.outputs.contains { $0.portType == .bluetoothA2DP }
        let isRouteSettlingStartFailure = nsError.domain == "com.apple.coreaudio.avfaudio" && nsError.code == 2003329396
        let isSessionPropertyFailure = nsError.code == 560557684

        return hasNoInputs || isBluetoothA2DPOnly || isRouteSettlingStartFailure || isSessionPropertyFailure
    }

    private func applyInputPreference() throws {
        let availableInputs = audioSession.availableInputs ?? []
        let action = AudioInputPreferenceResolver().resolve(
            availableInputs: availableInputs.map {
                AudioInputPreferenceResolver.Candidate(id: $0.uid, portType: $0.portType)
            },
            preferBuiltInMicrophone: preferBuiltInMicrophoneProvider()
        )

        switch action {
        case .preferInput(let id):
            guard let preferredInput = availableInputs.first(where: { $0.uid == id }) else { break }
            try audioSession.setPreferredInput(preferredInput)
        case .useSystemDefault:
            try audioSession.setPreferredInput(nil)
        case .keepCurrentRoute:
            break
        }

        refreshCurrentCaptureDeviceName()
    }

    func refreshCurrentCaptureDeviceName() {
        let portName = audioSession.currentRoute.inputs.first?.portName ?? "iPhone Microphone"
        currentCaptureDeviceName = AudioSilenceGatePolicy.normalizedMicrophoneName(portName)
    }
}

enum AudioRecorderError: LocalizedError {
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
