import Foundation

struct AudioSilenceGatePolicy {
    static let microphoneNameFallback = "current device"

    static let longCaptureMinimumDuration: TimeInterval = 2.0
    static let lowConfidenceRMSCutoff: Float = 0.0028
    static let minimumActiveSignalRunDuration: TimeInterval = 0.14
    static let longTrueSilenceMinimumDuration: TimeInterval = 5.0
    static let trueSilenceWindowSize = 1600
    static let trueSilenceWindowRMSThreshold: Float = 0.0014
    static let trueSilenceMinimumWindowRatio: Float = 0.95

    static func normalizedMicrophoneName(_ rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? microphoneNameFallback : trimmed
    }

    static func shouldRejectLikelySilence(
        captureDuration: TimeInterval,
        hadActiveSignal: Bool,
        speechRMS: Float
    ) -> Bool {
        guard captureDuration >= longCaptureMinimumDuration else { return false }
        guard !hadActiveSignal else { return false }
        return speechRMS < lowConfidenceRMSCutoff
    }

    static func shouldFlagLongTrueSilence(
        captureDuration: TimeInterval,
        hadActiveSignal: Bool,
        silentWindowRatio: Float
    ) -> Bool {
        guard captureDuration >= longTrueSilenceMinimumDuration else { return false }
        guard !hadActiveSignal else { return false }
        return silentWindowRatio >= trueSilenceMinimumWindowRatio
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
}
