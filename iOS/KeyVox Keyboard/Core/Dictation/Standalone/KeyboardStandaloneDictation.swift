import Foundation

/// Runs one dictation without the containing app: the microphone capture feeds the dictation
/// Audio Unit extension while the user speaks, and the extension's transcript comes back when
/// they stop.
@MainActor
final class KeyboardStandaloneDictation: KeyboardStandaloneDictating {
    private enum Phase {
        case idle
        case starting
        case recording
        case finishing
    }

    var onRecordingStarted: (() -> Void)?
    var onRecordingStartFailed: (() -> Void)?
    var onTranscribingStarted: (() -> Void)?
    var onTranscriptionReady: ((String) -> Void)?
    var onNoSpeech: (() -> Void)?
    var onFailure: (() -> Void)?

    private let capture: KeyboardMicrophoneCapture
    private let audioUnitClient: KeyboardDictationAudioUnitClient
    private let isAvailableProvider: () -> Bool
    private let selectedVibeIdentifierProvider: () -> String

    private var phase = Phase.idle
    /// Identifies the current dictation, so answers to an earlier one are ignored.
    private var dictationID = UUID()
    private var isCapturing = false
    private var isAudioUnitReady = false
    private var latestMeterSample: AudioIndicatorSample?

    init(
        capture: KeyboardMicrophoneCapture,
        audioUnitClient: KeyboardDictationAudioUnitClient = KeyboardDictationAudioUnitClient(),
        isAvailableProvider: @escaping () -> Bool,
        selectedVibeIdentifierProvider: @escaping () -> String
    ) {
        self.capture = capture
        self.audioUnitClient = audioUnitClient
        self.isAvailableProvider = isAvailableProvider
        self.selectedVibeIdentifierProvider = selectedVibeIdentifierProvider
        bindCapture()
    }

    var isAvailable: Bool {
        isAvailableProvider()
    }

    /// The live meter while recording, for the keyboard's audio indicator.
    var currentAudioIndicatorSample: AudioIndicatorSample? {
        phase == .recording ? latestMeterSample : nil
    }

    func prepare() {
        capture.prepare()
        audioUnitClient.prepare()
    }

    func start() {
        guard phase == .idle else { return }
        let dictationID = beginNewDictation()
        phase = .starting

        audioUnitClient.begin(styleIdentifier: selectedVibeIdentifierProvider()) { [weak self] accepted in
            guard let self, self.dictationID == dictationID else { return }
            guard accepted else {
                self.fail()
                return
            }
            self.isAudioUnitReady = true
            self.reportRecordingStartedIfReady()
        }
        capture.start()
    }

    func stop() {
        guard phase == .recording else { return }
        phase = .finishing
        capture.stop()
    }

    func cancel() {
        guard phase != .idle else { return }
        endDictation()
        audioUnitClient.cancel()
    }

    func deactivate() {
        endDictation()
        audioUnitClient.disconnect()
    }

    private func bindCapture() {
        capture.onStarted = { [weak self] in
            guard let self, self.phase == .starting else { return }
            self.isCapturing = true
            self.reportRecordingStartedIfReady()
        }
        capture.onAudio = { [weak self] samples, sampleRate in
            self?.forward(samples, sampleRate: sampleRate)
        }
        capture.onStopped = { [weak self] in
            guard let self, self.phase == .finishing else { return }
            self.awaitOutcome()
        }
        capture.onInterrupted = { [weak self] in
            self?.handleCaptureInterrupted()
        }
        capture.onFailure = { [weak self] in
            guard let self else { return }
            switch self.phase {
            case .starting:
                self.failToStartRecording()
            case .recording, .finishing:
                self.fail()
            case .idle:
                break
            }
        }
    }

    /// A call or another app's audio cut the recording off. What was said before then is
    /// transcribed, as the app does for a recording it has cut off.
    private func handleCaptureInterrupted() {
        switch phase {
        case .starting:
            failToStartRecording()
        case .recording:
            phase = .finishing
            onTranscribingStarted?()
            awaitOutcome()
        case .idle, .finishing:
            break
        }
    }

    private func reportRecordingStartedIfReady() {
        guard phase == .starting, isCapturing, isAudioUnitReady else { return }
        phase = .recording
        onRecordingStarted?()
    }

    private func forward(_ samples: Data, sampleRate: Double) {
        // Audio captured before the extension took the dictation waits in the client's queue.
        guard phase != .idle else { return }
        let dictationID = dictationID
        audioUnitClient.append(audio: samples, sampleRate: sampleRate) { [weak self] meter in
            guard let self, self.dictationID == dictationID, self.isAudioUnitReady else { return }
            guard let meter else {
                self.fail()
                return
            }
            self.latestMeterSample = AudioIndicatorSample(
                level: meter.level,
                signalState: meter.signalState.audioIndicatorSignalState,
                timestamp: Date().timeIntervalSince1970
            )
        }
    }

    private func awaitOutcome() {
        let dictationID = dictationID
        audioUnitClient.finish { [weak self] outcome in
            guard let self, self.dictationID == dictationID else { return }
            switch outcome {
            case .transcript(let text):
                self.endDictation()
                self.onTranscriptionReady?(text)
            case .noSpeech:
                self.endDictation()
                self.onNoSpeech?()
            case .failed:
                self.fail()
            }
        }
    }

    /// The microphone could not be had, so there is nothing the containing app could do better.
    private func failToStartRecording() {
        endDictation()
        audioUnitClient.cancel()
        onRecordingStartFailed?()
    }

    private func fail() {
        endDictation()
        audioUnitClient.disconnect()
        onFailure?()
    }

    @discardableResult
    private func beginNewDictation() -> UUID {
        dictationID = UUID()
        isCapturing = false
        isAudioUnitReady = false
        latestMeterSample = nil
        return dictationID
    }

    private func endDictation() {
        if phase == .starting || phase == .recording {
            capture.cancel()
        }
        phase = .idle
        beginNewDictation()
    }
}
