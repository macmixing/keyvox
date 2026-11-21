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

    /// Dictations finishing after their keyboard went away, kept until their transcript arrives.
    private static var dictationsFinishingInBackground: [KeyboardStandaloneDictation] = []
    /// How many keyboards have their dictation prepared and not yet deactivated; the extension's
    /// models are shared, so they are freed only when none is left.
    private static var preparedDictationCount = 0

    private let capture: KeyboardMicrophoneCapture
    private let audioUnitClient: KeyboardTranscriptionAUClient
    private let rescuedDictationStore: KeyboardRescuedDictationStore
    private let isAvailableProvider: () -> Bool
    private let selectedVibeIdentifierProvider: () -> String

    private var phase = Phase.idle
    /// Identifies the current dictation, so answers to an earlier one are ignored.
    private var dictationID = UUID()
    private var isCapturing = false
    private var isAudioUnitReady = false
    private var latestMeterSample: AudioIndicatorSample?
    private var isPrepared = false
    private var isFinishingInBackground = false
    private var isAwaitingOutcome = false
    /// The keyboard went away while the dictation was finishing; the extension is let go of once
    /// it is done.
    private var isDeactivationPending = false

    init(
        capture: KeyboardMicrophoneCapture,
        audioUnitClient: KeyboardTranscriptionAUClient = KeyboardTranscriptionAUClient(),
        rescuedDictationStore: KeyboardRescuedDictationStore,
        isAvailableProvider: @escaping () -> Bool,
        selectedVibeIdentifierProvider: @escaping () -> String
    ) {
        self.capture = capture
        self.audioUnitClient = audioUnitClient
        self.rescuedDictationStore = rescuedDictationStore
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
        if !isPrepared {
            isPrepared = true
            Self.preparedDictationCount += 1
        }
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

    func finishInBackground() {
        guard phase == .recording || phase == .finishing, !isFinishingInBackground else { return }
        isFinishingInBackground = true
        Self.dictationsFinishingInBackground.append(self)
        // A page the keyboard no longer shows may never report its capture stopped, so the
        // extension is asked for the transcript of what it has without waiting for it.
        guard !isAwaitingOutcome else { return }
        capture.cancel()
        phase = .finishing
        awaitOutcome()
    }

    func cancel() {
        guard phase != .idle, !isFinishingInBackground else { return }
        endDictation()
        audioUnitClient.cancel()
    }

    func deactivate() {
        if isPrepared {
            isPrepared = false
            Self.preparedDictationCount -= 1
        }
        guard !isFinishingInBackground else {
            isDeactivationPending = true
            return
        }
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
            guard let self, self.phase == .finishing, !self.isFinishingInBackground else { return }
            self.awaitOutcome()
        }
        capture.onInterrupted = { [weak self] in
            self?.handleCaptureInterrupted()
        }
        capture.onBusy = { [weak self] in
            guard let self, self.phase == .starting else { return }
            self.failToStartRecording()
        }
        capture.onFailure = { [weak self] in
            guard let self, self.phase != .idle else { return }
            self.fail()
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
        guard !isAwaitingOutcome else { return }
        isAwaitingOutcome = true
        let dictationID = dictationID
        audioUnitClient.finish { [weak self] outcome in
            guard let self, self.dictationID == dictationID else { return }
            self.isAwaitingOutcome = false
            if self.isFinishingInBackground {
                if case .transcript(let text) = outcome {
                    self.rescuedDictationStore.save(Self.rescuedDictation(text))
                }
                self.endFinishingInBackground()
                return
            }
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

    /// A call holds the microphone, so the containing app could not record either.
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

    /// The extension publishes the transcript before answering, so the published dictation's
    /// identity is kept with it when it is this transcript.
    private static func rescuedDictation(_ text: String) -> KeyboardRescuedDictationStore.Dictation {
        let isPublished = KeyVoxIPCBridge.latestTranscription() == text
        return KeyboardRescuedDictationStore.Dictation(
            text: text,
            artifactID: isPublished ? KeyVoxIPCBridge.latestTranscriptionID() : nil,
            styleIdentifier: isPublished ? KeyVoxIPCBridge.latestTranscriptionStyleIdentifier() : nil
        )
    }

    private func endFinishingInBackground() {
        isFinishingInBackground = false
        Self.dictationsFinishingInBackground.removeAll { $0 === self }
        phase = .idle
        beginNewDictation()
        if isDeactivationPending {
            isDeactivationPending = false
            if Self.preparedDictationCount > 0 {
                audioUnitClient.releaseConnection()
            } else {
                audioUnitClient.disconnect()
            }
        }
    }

    @discardableResult
    private func beginNewDictation() -> UUID {
        dictationID = UUID()
        isAwaitingOutcome = false
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
