import Foundation
import AVFoundation
import KeyVoxCore

extension AudioRecorder {
    func startRecordingSession() {
        guard !isRecording, !isStopFinalizationPending else { return }

        let session = AVCaptureSession()
        session.beginConfiguration()

        // App-scoped input selection: selected mic -> built-in -> first available.
        guard let device = AudioDeviceManager.shared.resolvedCaptureDevice()
            ?? AudioDeviceManager.shared.builtInCaptureDevice()
            ?? AVCaptureDevice.default(for: .audio)
            ?? Self.captureAudioDevices().first else {
            session.commitConfiguration()
            return
        }

        let input: AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: device)
        } catch {
            session.commitConfiguration()
            return
        }

        guard session.canAddInput(input) else {
            session.commitConfiguration()
            return
        }
        session.addInput(input)

        let output = AVCaptureAudioDataOutput()
        output.setSampleBufferDelegate(self, queue: captureQueue)

        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)

        session.commitConfiguration()

        captureSession = session
        captureInput = input
        audioCaptureOutput = output

        // Map current device kind for conditional logic upstream
        currentDeviceKind = AudioDeviceManager.shared.availableMicrophones.first(where: { $0.id == device.uniqueID })?.kind ?? .builtIn
        currentCaptureDeviceName = AudioSilenceGatePolicy.normalizedMicrophoneName(device.localizedName)
        configureSessionSilenceThresholds(for: device)

        // Converter is rebuilt lazily when first buffer arrives (or source format changes).
        converter = nil

        audioDataQueue.sync {
            audioData.removeAll()
        }

        lastCaptureWasAbsoluteSilence = false
        lastCaptureHadActiveSignal = false
        lastCaptureWasLikelySilence = false
        lastCaptureWasLongTrueSilence = false
        lastCaptureDuration = 0

        lastNonDeadSignalTime = Date.distantPast
        lastVisualActiveSignalTime = Date.distantPast
        currentActiveSignalRunDuration = 0
        maxActiveSignalRunDuration = 0
        lastCaptureHadNonDeadSignal = false
        captureStartedAt = Date()
        DispatchQueue.main.async {
            self.audioLevel = 0
            self.isVisualQuiet = true
            self.liveInputSignalState = .dead
        }

        session.startRunning()
        isRecording = true
    }

    func stopRecordingSession(completion: @escaping ([Float]) -> Void) {
        guard isRecording else {
            completion(outputFramesForStoppedCapture())
            return
        }
        guard !isStopFinalizationPending else { return }

        isStopFinalizationPending = true
        captureQueue.async { [weak self] in
            self?.finalizeStopRecordingSession(completion: completion)
        }
    }

    private func drainPendingCaptureQueueWork() {
        guard DispatchQueue.getSpecific(key: captureQueueSpecificKey) != captureQueueSpecificValue else {
            return
        }
        captureQueue.sync {}
    }

    private func finalizeStopRecordingSession(completion: @escaping ([Float]) -> Void) {
        audioCaptureOutput?.setSampleBufferDelegate(nil, queue: nil)

        // Finalize from the capture queue so anything already queued for delivery
        // lands in the buffer before we tear the session down.
        if let session = captureSession {
            session.beginConfiguration()
            if let input = captureInput {
                session.removeInput(input)
            }
            if let output = audioCaptureOutput {
                session.removeOutput(output)
            }
            session.commitConfiguration()
            session.stopRunning()
        }

        drainPendingCaptureQueueWork()

        captureSession = nil
        captureInput = nil
        audioCaptureOutput = nil
        converter = nil
        isRecording = false
        isStopFinalizationPending = false

        let outputFrames = outputFramesForStoppedCapture()
        DispatchQueue.main.async {
            completion(outputFrames)
        }
    }
}
