import AVFoundation
import Combine
import Foundation
import KeyVoxCore

protocol iOSAudioRecording: AnyObject {
    var isRecording: Bool { get }
    var isMonitoring: Bool { get }
    var currentCaptureDeviceName: String { get }
    var lastCaptureWasAbsoluteSilence: Bool { get }
    var lastCaptureHadActiveSignal: Bool { get }
    var lastCaptureWasLikelySilence: Bool { get }
    var lastCaptureWasLongTrueSilence: Bool { get }
    var lastCaptureDuration: TimeInterval { get }
    var maxActiveSignalRunDuration: TimeInterval { get }

    func startRecording() async throws
    func stopRecording() async -> iOSStoppedCapture
    func ensureEngineRunning() throws
}

@MainActor
final class iOSAudioRecorder: ObservableObject, iOSAudioRecording {
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
    var audioEngine: AVAudioEngine?
    let streamingState = iOSAudioCaptureAccumulator()
    var heartbeatCallback: (() -> Void)?

    init(audioSession: AVAudioSession = .sharedInstance()) {
        self.audioSession = audioSession
        self.sessionActiveSignalRMSThreshold = baseActiveSignalRMSThreshold
        self.sessionGapRemovalRMSThreshold = baseGapRemovalRMSThreshold
    }
}
