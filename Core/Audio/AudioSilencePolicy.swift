import Foundation

struct AudioSilenceGatePolicy {
    static let microphoneNameFallback = "current device"

    static let longCaptureMinimumDuration: TimeInterval = 2.0
    static let lowConfidenceRMSCutoff: Float = 0.0032
    static let minimumActiveSignalRunDuration: TimeInterval = 0.22
    static let longTrueSilenceMinimumDuration: TimeInterval = 3.0
    static let trueSilenceWindowSize = 1600
    static let trueSilenceWindowRMSThreshold: Float = 0.0018
    static let trueSilenceMinimumWindowRatio: Float = 0.93
    static let likelySilenceMinimumWindowRatioWhenActiveSignal: Float = 0.9
    static let longTrueSilenceMinimumWindowRatioWhenActiveSignal: Float = 0.985
    static let defaultInputVolumeScalar: Float = 0.5
    static let inputVolumeNeutralScalar: Float = 0.5
    static let thresholdScaleMinimum: Float = 0.75
    static let thresholdScaleMaximum: Float = 1.6
    static let ambientFloorPercentile: Float = 0.2
    static let noiseDominatedMinimumAmbientFloorRMS: Float = 0.00045
    static let noiseDominatedSpeechToAmbientRatioWithoutActiveSignal: Float = 1.5
    static let noiseDominatedSpeechToAmbientRatioWithActiveSignal: Float = 1.22

    static func normalizedMicrophoneName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? microphoneNameFallback : trimmed
    }

    static func shouldRejectLikelySilence(
        captureDuration: TimeInterval,
        hadActiveSignal: Bool,
        silentWindowRatio: Float,
        speechRMS: Float,
        lowConfidenceRMSCutoff: Float = AudioSilenceGatePolicy.lowConfidenceRMSCutoff,
        ambientFloorRMS: Float = 0
    ) -> Bool {
        guard captureDuration >= longCaptureMinimumDuration else { return false }
        if speechRMS < lowConfidenceRMSCutoff {
            if !hadActiveSignal { return true }
            return silentWindowRatio >= likelySilenceMinimumWindowRatioWhenActiveSignal
        }
        return shouldRejectNoiseDominatedCapture(
            hadActiveSignal: hadActiveSignal,
            speechRMS: speechRMS,
            ambientFloorRMS: ambientFloorRMS
        )
    }

    static func shouldFlagLongTrueSilence(
        captureDuration: TimeInterval,
        hadActiveSignal: Bool,
        silentWindowRatio: Float
    ) -> Bool {
        guard captureDuration >= longTrueSilenceMinimumDuration else { return false }
        if !hadActiveSignal {
            return silentWindowRatio >= trueSilenceMinimumWindowRatio
        }
        return silentWindowRatio >= longTrueSilenceMinimumWindowRatioWhenActiveSignal
    }

    static func hadActiveSpeechEvidence(
        maxActiveSignalRunDuration: TimeInterval
    ) -> Bool {
        maxActiveSignalRunDuration >= minimumActiveSignalRunDuration
    }

    static func trueSilenceWindowRatio(
        for samples: [Float],
        windowSize: Int = trueSilenceWindowSize,
        silenceThreshold: Float = trueSilenceWindowRMSThreshold
    ) -> Float {
        AudioSignalMetrics.trueSilenceWindowRatio(
            for: samples,
            windowSize: windowSize,
            silenceThreshold: silenceThreshold
        )
    }

    static func thresholdScale(forInputVolume inputVolume: Float) -> Float {
        let clampedInputVolume = min(max(inputVolume, 0), 1)
        let rawScale = clampedInputVolume / inputVolumeNeutralScalar
        return min(max(rawScale, thresholdScaleMinimum), thresholdScaleMaximum)
    }

    static func shouldRejectNoiseDominatedCapture(
        hadActiveSignal: Bool,
        speechRMS: Float,
        ambientFloorRMS: Float
    ) -> Bool {
        guard ambientFloorRMS >= noiseDominatedMinimumAmbientFloorRMS else { return false }

        let requiredRatio = hadActiveSignal
            ? noiseDominatedSpeechToAmbientRatioWithActiveSignal
            : noiseDominatedSpeechToAmbientRatioWithoutActiveSignal
        return speechRMS < ambientFloorRMS * requiredRatio
    }
}
