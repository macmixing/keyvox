import AVFoundation

/// The capture format and signal thresholds every KeyVox dictation capture is shaped by.
enum AudioCaptureTuning {
    static var outputFormat: AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!
    }

    static let normalizationTargetPeak: Float = 0.9
    static let normalizationMaxGain: Float = 3.0
    static let deadSignalPeakThreshold: Float = 0.00012
    static let activeSignalRMSThreshold: Float = 0.003
    static let gapRemovalRMSThreshold: Float = 0.0023
    static let deadStateHoldDuration: TimeInterval = 0.35
    static let visualActiveStateHoldDuration: TimeInterval = 0.16
    static let visualActiveSignalThresholdMultiplier: Float = 1.85
}
