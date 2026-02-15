import Foundation

struct AudioCaptureClassification {
    let captureDuration: TimeInterval
    let hadActiveSignal: Bool
    let isAbsoluteSilence: Bool
    let silentWindowRatio: Float
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
        maxActiveSignalRunDuration: TimeInterval
    ) -> AudioCaptureClassification {
        let isAbsoluteSilence = AudioSignalMetrics.peak(of: snapshot) < absoluteSilencePeakThreshold
        let hadActiveSignal = AudioSilenceGatePolicy.hadActiveSpeechEvidence(
            maxActiveSignalRunDuration: maxActiveSignalRunDuration
        )
        let silentWindowRatio = AudioSilenceGatePolicy.trueSilenceWindowRatio(for: snapshot)
        let isLongTrueSilence = AudioSilenceGatePolicy.shouldFlagLongTrueSilence(
            captureDuration: captureDuration,
            hadActiveSignal: hadActiveSignal,
            silentWindowRatio: silentWindowRatio
        )
        let speechRMS = AudioSignalMetrics.rms(of: speechOnly)
        let shouldRejectLikelySilence = AudioSilenceGatePolicy.shouldRejectLikelySilence(
            captureDuration: captureDuration,
            hadActiveSignal: hadActiveSignal,
            speechRMS: speechRMS
        )

        return AudioCaptureClassification(
            captureDuration: captureDuration,
            hadActiveSignal: hadActiveSignal,
            isAbsoluteSilence: isAbsoluteSilence,
            silentWindowRatio: silentWindowRatio,
            isLongTrueSilence: isLongTrueSilence,
            speechRMS: speechRMS,
            shouldRejectLikelySilence: shouldRejectLikelySilence
        )
    }
}
