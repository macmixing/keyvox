import Foundation

public struct AudioSilenceGatePolicy {
    public static let microphoneNameFallback = "current device"

    public static let longCaptureMinimumDuration: TimeInterval = 2.0
    public static let lowConfidenceRMSCutoff: Float = 0.0032
    public static let minimumActiveSignalRunDuration: TimeInterval = 0.22
    public static let longTrueSilenceMinimumDuration: TimeInterval = 3.0
    public static let trueSilenceWindowSize = 1600
    public static let trueSilenceWindowRMSThreshold: Float = 0.0018
    public static let trueSilenceMinimumWindowRatio: Float = 0.93
    public static let likelySilenceMinimumWindowRatioWhenActiveSignal: Float = 0.9
    public static let longTrueSilenceMinimumWindowRatioWhenActiveSignal: Float = 0.985
    public static let defaultInputVolumeScalar: Float = 0.5
    public static let inputVolumeNeutralScalar: Float = 0.5
    public static let thresholdScaleMinimum: Float = 0.75
    public static let thresholdScaleMaximum: Float = 1.6
    public static let ambientFloorPercentile: Float = 0.2
    public static let noiseDominatedMinimumAmbientFloorRMS: Float = 0.00045
    public static let noiseDominatedSpeechToAmbientRatioWithoutActiveSignal: Float = 1.5
    public static let noiseDominatedSpeechToAmbientRatioWithActiveSignal: Float = 1.22

    public static func normalizedMicrophoneName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? microphoneNameFallback : trimmed
    }

    public static func shouldRejectLikelySilence(
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

    public static func shouldFlagLongTrueSilence(
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

    public static func hadActiveSpeechEvidence(
        maxActiveSignalRunDuration: TimeInterval
    ) -> Bool {
        maxActiveSignalRunDuration >= minimumActiveSignalRunDuration
    }

    public static func trueSilenceWindowRatio(
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

    public static func thresholdScale(forInputVolume inputVolume: Float) -> Float {
        let clampedInputVolume = min(max(inputVolume, 0), 1)
        let rawScale = clampedInputVolume / inputVolumeNeutralScalar
        return min(max(rawScale, thresholdScaleMinimum), thresholdScaleMaximum)
    }

    public static func shouldRejectNoiseDominatedCapture(
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
