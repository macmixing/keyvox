import Foundation

struct AudioCaptureClassification {
    let captureDuration: TimeInterval
    let hadActiveSignal: Bool
    let isAbsoluteSilence: Bool
    let silentWindowRatio: Float
    let ambientFloorRMS: Float
    let isLongTrueSilence: Bool
    let speechRMS: Float
    let shouldRejectLikelySilence: Bool
}

enum AudioCaptureClassifier {
    private static let absoluteSilencePeakThreshold: Float = 0.0001

    static func classify(
        snapshot: [Float],
        speechOnly: [Float],
        captureDuration: TimeInterval,
        maxActiveSignalRunDuration: TimeInterval,
        lowConfidenceRMSCutoff: Float = AudioSilenceGatePolicy.lowConfidenceRMSCutoff,
        trueSilenceWindowRMSThreshold: Float = AudioSilenceGatePolicy.trueSilenceWindowRMSThreshold
    ) -> AudioCaptureClassification {
        let isAbsoluteSilence = AudioSignalMetrics.peak(of: snapshot) < absoluteSilencePeakThreshold
        let hadActiveSignal = AudioSilenceGatePolicy.hadActiveSpeechEvidence(
            maxActiveSignalRunDuration: maxActiveSignalRunDuration
        )
        let ambientFloorRMS = AudioSignalMetrics.ambientFloorRMS(
            of: snapshot,
            windowSize: AudioSilenceGatePolicy.trueSilenceWindowSize,
            percentile: AudioSilenceGatePolicy.ambientFloorPercentile
        )
        let silentWindowRatio = AudioSilenceGatePolicy.trueSilenceWindowRatio(
            for: snapshot,
            silenceThreshold: trueSilenceWindowRMSThreshold
        )
        let isLongTrueSilence = AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
            captureDuration: captureDuration,
            hadActiveSignal: hadActiveSignal,
            silentWindowRatio: silentWindowRatio
        )
        let speechRMS = AudioSignalMetrics.rms(of: speechOnly)
        let shouldRejectLikelySilence = AudioSilenceGatePolicy.shouldRejectLikelySilence(
            captureDuration: captureDuration,
            hadActiveSignal: hadActiveSignal,
            silentWindowRatio: silentWindowRatio,
            speechRMS: speechRMS,
            lowConfidenceRMSCutoff: lowConfidenceRMSCutoff,
            ambientFloorRMS: ambientFloorRMS
        )

        return AudioCaptureClassification(
            captureDuration: captureDuration,
            hadActiveSignal: hadActiveSignal,
            isAbsoluteSilence: isAbsoluteSilence,
            silentWindowRatio: silentWindowRatio,
            ambientFloorRMS: ambientFloorRMS,
            isLongTrueSilence: isLongTrueSilence,
            speechRMS: speechRMS,
            shouldRejectLikelySilence: shouldRejectLikelySilence
        )
    }
}
