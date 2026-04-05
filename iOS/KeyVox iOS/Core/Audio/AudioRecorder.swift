import AVFoundation
import Combine
import Foundation
import KeyVoxCore

protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var isMonitoring: Bool { get }
    var currentCaptureDeviceName: String { get }
    var currentCaptureDuration: TimeInterval { get }
    var hasMeaningfulSpeechInCurrentCapture: Bool { get }
    var timeSinceLastMeaningfulSpeech: TimeInterval? { get }
    var lastCaptureWasAbsoluteSilence: Bool { get }
    var lastCaptureHadActiveSignal: Bool { get }
    var lastCaptureWasLikelySilence: Bool { get }
    var lastCaptureWasLongTrueSilence: Bool { get }
    var lastCaptureDuration: TimeInterval { get }
    var maxActiveSignalRunDuration: TimeInterval { get }

    func enableMonitoring() async throws
    func repairMonitoringAfterPlayback() async throws
    func startRecording() async throws
    func stopRecording() async -> StoppedCapture
    func ensureEngineRunning() throws
    func stopMonitoring() throws
    func cancelCurrentUtterance()
}

@MainActor
final class AudioRecorder: ObservableObject, AudioRecording {
    let outputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!
    let normalizationTargetPeak: Float = 0.9
    let normalizationMaxGain: Float = 3.0
    let deadSignalPeakThreshold: Float = 0.00012
    let baseActiveSignalRMSThreshold: Float = 0.003
    let baseGapRemovalRMSThreshold: Float = 0.0023
    let deadStateHoldDuration: TimeInterval = 0.35
    let visualActiveStateHoldDuration: TimeInterval = 0.16
    let visualActiveSignalThresholdMultiplier: Float = 1.85

    @Published var isRecording = false
    @Published var isMonitoring = false
    @Published var audioLevel: Float = 0
    @Published var liveInputSignalState: LiveInputSignalState = .dead
    @Published var currentCaptureDeviceName: String = "iPhone Microphone"

    var lastCaptureWasAbsoluteSilence = false
    var lastCaptureHadActiveSignal = false
    var lastCaptureWasLikelySilence = false
    var lastCaptureWasLongTrueSilence = false
    var lastCaptureDuration: TimeInterval = 0
    var lastCaptureHadNonDeadSignal = false
    var maxActiveSignalRunDuration: TimeInterval = 0

    var sessionActiveSignalRMSThreshold: Float = 0.003
    var sessionGapRemovalRMSThreshold: Float = 0.0023
    var sessionLikelySilenceRMSCutoff: Float = AudioSilenceGatePolicy.lowConfidenceRMSCutoff
    var sessionTrueSilenceWindowRMSThreshold: Float = AudioSilenceGatePolicy.trueSilenceWindowRMSThreshold
    var captureStartedAt = Date.distantPast

    let audioSession: AVAudioSession
    let preferBuiltInMicrophoneProvider: () -> Bool
    var audioEngine: AVAudioEngine?
    let streamingState = AudioCaptureAccumulator()
    var heartbeatCallback: (() -> Void)?
    var liveMeterUpdateHandler: ((Float, LiveInputSignalState) -> Void)?
    var audioInterruptedCaptureHandler: ((StoppedCapture) -> Void)?
    var audioSessionInterruptedHandler: (() -> Void)?
    var engineConfigurationObserver: NSObjectProtocol?
    var audioSessionInterruptionObserver: NSObjectProtocol?

    init(
        audioSession: AVAudioSession = .sharedInstance(),
        preferBuiltInMicrophoneProvider: @escaping () -> Bool = { true }
    ) {
        self.audioSession = audioSession
        self.preferBuiltInMicrophoneProvider = preferBuiltInMicrophoneProvider
        self.sessionActiveSignalRMSThreshold = baseActiveSignalRMSThreshold
        self.sessionGapRemovalRMSThreshold = baseGapRemovalRMSThreshold
        refreshCurrentCaptureDeviceName()
        configureEngineConfigurationObserver()
        configureAudioSessionInterruptionObserver()
    }

    deinit {
        MainActor.assumeIsolated {
            removeEngineConfigurationObserver()
            removeAudioSessionInterruptionObserver()
        }
    }

    var currentCaptureDuration: TimeInterval {
        streamingState.liveMetrics(sampleRate: outputFormat.sampleRate).duration
    }

    var hasMeaningfulSpeechInCurrentCapture: Bool {
        streamingState.liveMetrics(sampleRate: outputFormat.sampleRate).hadMeaningfulSpeech
    }

    var timeSinceLastMeaningfulSpeech: TimeInterval? {
        streamingState.liveMetrics(sampleRate: outputFormat.sampleRate).timeSinceLastMeaningfulSpeech
    }
}
