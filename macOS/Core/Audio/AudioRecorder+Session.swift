import Foundation
import AVFoundation
import KeyVoxCore

extension AudioRecorder {
    func prepareRecordingSession() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .authorized else { return }
        guard let device = resolvedRecordingDevice() else { return }
        let deviceKind = AudioDeviceManager.shared.availableMicrophones.first(where: { $0.id == device.uniqueID })?.kind ?? .builtIn
        guard deviceKind == .wiredOrOther else { return }

        captureQueue.async { [weak self] in
            self?.prepareInputCapture(for: device)
        }
    }

    private func prepareInputCapture(for device: AVCaptureDevice) {
        let inputCapture = audioInputCapture ?? AudioEngineInputCapture()
        do {
            try inputCapture.prepare(
                deviceUID: device.uniqueID,
                deliveryQueue: captureQueue
            ) { [weak self] buffer in
                self?.processCapturedBuffer(buffer)
            }
            audioInputCapture = inputCapture
        } catch {
            audioInputCapture = nil
        }
    }

    func startRecordingSession() -> Bool {
        guard !isRecording, !isStopFinalizationPending else { return false }

        // App-scoped input selection: selected mic -> built-in -> first available.
        guard let device = resolvedRecordingDevice() else {
            return false
        }

        // Map current device kind for conditional logic upstream
        currentDeviceKind = AudioDeviceManager.shared.availableMicrophones.first(where: { $0.id == device.uniqueID })?.kind ?? .builtIn
        currentCaptureDeviceName = AudioSilenceGatePolicy.normalizedMicrophoneName(device.localizedName)
        configureSessionSilenceThresholds(for: device)

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
        visualMeterPreviousInput = 0
        visualMeterPreviousOutput = 0
        currentActiveSignalRunDuration = 0
        maxActiveSignalRunDuration = 0
        lastCaptureHadNonDeadSignal = false
        captureStartedAt = Date()
        DispatchQueue.main.async {
            self.audioLevel = 0
            self.isVisualQuiet = true
            self.liveInputSignalState = .dead
        }

        let didStartCapture: Bool
        switch currentDeviceKind {
        case .builtIn, .airPods, .bluetooth:
            didStartCapture = startAVCaptureSession(device: device)
        case .wiredOrOther:
            didStartCapture = captureQueue.sync {
                startAudioEngineCapture(device: device)
            }
        }
        guard didStartCapture else {
            return false
        }

        isRecording = true
        return true
    }

    func stopRecordingSession(completion: @escaping ([Float]) -> Void) {
        guard isRecording else {
            completion(outputFramesForStoppedCapture())
            return
        }
        guard !isStopFinalizationPending else { return }

        isStopFinalizationPending = true
        if captureSession == nil {
            audioInputCapture?.stop()
        }
        captureQueue.async { [weak self] in
            self?.finalizeStopRecordingSession(completion: completion)
        }
    }

    private func finalizeStopRecordingSession(completion: @escaping ([Float]) -> Void) {
        if let captureSession {
            audioCaptureOutput?.setSampleBufferDelegate(nil, queue: nil)
            captureSession.beginConfiguration()
            if let captureInput {
                captureSession.removeInput(captureInput)
            }
            if let audioCaptureOutput {
                captureSession.removeOutput(audioCaptureOutput)
            }
            captureSession.commitConfiguration()
            captureSession.stopRunning()
            self.captureSession = nil
            captureInput = nil
            audioCaptureOutput = nil
        }

        drainPendingCaptureQueueWork()

        converter = nil
        isRecording = false
        isStopFinalizationPending = false

        let outputFrames = outputFramesForStoppedCapture()
        DispatchQueue.main.async {
            completion(outputFrames)
        }
    }

    private func drainPendingCaptureQueueWork() {
        guard DispatchQueue.getSpecific(key: captureQueueSpecificKey) != captureQueueSpecificValue else {
            return
        }
        captureQueue.sync {}
    }

    private func resolvedRecordingDevice() -> AVCaptureDevice? {
        AudioDeviceManager.shared.resolvedCaptureDevice()
            ?? AudioDeviceManager.shared.builtInCaptureDevice()
            ?? AVCaptureDevice.default(for: .audio)
            ?? Self.captureAudioDevices().first
    }

    private func startAVCaptureSession(device: AVCaptureDevice) -> Bool {
        audioInputCapture?.stop()
        audioInputCapture = nil

        let session = AVCaptureSession()
        session.beginConfiguration()

        do {
            let input = try AVCaptureDeviceInput(device: device)
            guard session.canAddInput(input) else {
                session.commitConfiguration()
                return false
            }
            session.addInput(input)

            let output = AVCaptureAudioDataOutput()
            output.setSampleBufferDelegate(self, queue: captureQueue)
            guard session.canAddOutput(output) else {
                output.setSampleBufferDelegate(nil, queue: nil)
                session.commitConfiguration()
                return false
            }
            session.addOutput(output)
            session.commitConfiguration()

            captureSession = session
            captureInput = input
            audioCaptureOutput = output
            session.startRunning()
            return true
        } catch {
            session.commitConfiguration()
            return false
        }
    }

    private func startAudioEngineCapture(device: AVCaptureDevice) -> Bool {
        let inputCapture = audioInputCapture ?? AudioEngineInputCapture()
        do {
            try inputCapture.start(
                deviceUID: device.uniqueID,
                deliveryQueue: captureQueue
            ) { [weak self] buffer in
                self?.processCapturedBuffer(buffer)
            }
            audioInputCapture = inputCapture
            return true
        } catch {
            return false
        }
    }
}
