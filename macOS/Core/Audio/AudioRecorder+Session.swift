import Foundation
import AVFoundation
import KeyVoxCore

extension AudioRecorder {
    func startRecordingSession() {
        guard !isRecording, !isStopFinalizationPending else { return }

        // App-scoped input selection: selected mic -> built-in -> first available.
        guard let device = AudioDeviceManager.shared.resolvedCaptureDevice()
            ?? AudioDeviceManager.shared.builtInCaptureDevice()
            ?? AVCaptureDevice.default(for: .audio)
            ?? Self.captureAudioDevices().first else {
            return
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

        let inputCapture = AudioEngineInputCapture()
        do {
            try inputCapture.start(
                deviceUID: device.uniqueID,
                deliveryQueue: captureQueue
            ) { [weak self] buffer in
                self?.processCapturedBuffer(buffer)
            }
        } catch {
            return
        }

        audioInputCapture = inputCapture
        isRecording = true
    }

    func stopRecordingSession(completion: @escaping ([Float]) -> Void) {
        guard isRecording else {
            completion(outputFramesForStoppedCapture())
            return
        }
        guard !isStopFinalizationPending else { return }

        isStopFinalizationPending = true
        audioInputCapture?.stop()
        captureQueue.async { [weak self] in
            self?.finalizeStopRecordingSession(completion: completion)
        }
    }

    private func finalizeStopRecordingSession(completion: @escaping ([Float]) -> Void) {
        audioInputCapture = nil
        converter = nil
        isRecording = false
        isStopFinalizationPending = false

        let outputFrames = outputFramesForStoppedCapture()
        DispatchQueue.main.async {
            completion(outputFrames)
        }
    }
}
