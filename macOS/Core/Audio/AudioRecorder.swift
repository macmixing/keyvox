import Foundation
import AVFoundation
import Combine
import KeyVoxCore

enum LiveInputSignalState: Equatable {
    case dead
    case quiet
    case active
}

class AudioRecorder: NSObject, ObservableObject {
    var captureSession: AVCaptureSession?
    var captureInput: AVCaptureDeviceInput?
    var audioCaptureOutput: AVCaptureAudioDataOutput?
    var converter: AVAudioConverter?
    var isStopFinalizationPending = false

    var audioData: [Float] = []
    let audioDataQueue = DispatchQueue(label: "AudioRecorder.audioDataQueue")
    let captureQueueSpecificKey = DispatchSpecificKey<UInt8>()
    let captureQueueSpecificValue: UInt8 = 1
    lazy var captureQueue: DispatchQueue = {
        let queue = DispatchQueue(label: "AudioRecorder.captureQueue")
        queue.setSpecific(key: captureQueueSpecificKey, value: captureQueueSpecificValue)
        return queue
    }()
    // Recorder contract is still mono Float32 @ 16kHz for downstream transcription.
    let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!
    let normalizationTargetPeak: Float = 0.9
    let normalizationMaxGain: Float = 3.0
    var stopCaptureTailDuration: TimeInterval = 0.18

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var isVisualQuiet = true
    @Published var liveInputSignalState: LiveInputSignalState = .dead
    @Published var currentDeviceKind: MicrophoneKind = .builtIn
    @Published var currentCaptureDeviceName: String = AudioSilenceGatePolicy.microphoneNameFallback
    @Published var lastCaptureWasAbsoluteSilence: Bool = false
    @Published var lastCaptureHadActiveSignal: Bool = false
    @Published var lastCaptureWasLikelySilence: Bool = false
    @Published var lastCaptureWasLongTrueSilence: Bool = false
    @Published var lastCaptureDuration: TimeInterval = 0
    let deadSignalPeakThreshold: Float = 0.00012
    let baseActiveSignalRMSThreshold: Float = 0.003
    let baseGapRemovalRMSThreshold: Float = 0.0023
    var sessionActiveSignalRMSThreshold: Float = 0.003
    var sessionGapRemovalRMSThreshold: Float = 0.0023
    var sessionLikelySilenceRMSCutoff: Float = AudioSilenceGatePolicy.lowConfidenceRMSCutoff
    var sessionTrueSilenceWindowRMSThreshold: Float = AudioSilenceGatePolicy.trueSilenceWindowRMSThreshold
    var sessionInputVolumeScalar: Float = AudioSilenceGatePolicy.defaultInputVolumeScalar
    var sessionThresholdScale: Float = 1.0
    let deadStateHoldDuration: TimeInterval = 0.35
    let visualActiveStateHoldDuration: TimeInterval = 0.16
    let visualActiveSignalThresholdMultiplier: Float = 1.85
    var lastNonDeadSignalTime: Date = Date.distantPast
    var lastVisualActiveSignalTime: Date = Date.distantPast
    var currentActiveSignalRunDuration: TimeInterval = 0
    var maxActiveSignalRunDuration: TimeInterval = 0
    var lastCaptureHadNonDeadSignal: Bool = false
    var captureStartedAt = Date.distantPast

    func startRecording() {
        startRecordingSession()
    }

    func stopRecording(completion: @escaping ([Float]) -> Void) {
        stopRecordingSession(completion: completion)
    }
}
