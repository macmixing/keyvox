import Foundation

enum TTSPlaybackCoordinatorBufferingPolicy {
    static let singleChunkStartBufferedSeconds: Double = 0.45
    static let multiChunkMinimumRunwaySeconds: Double = 1.2
    static let fastModeSingleChunkStartBufferedSeconds: Double = 0.30
    static let fastModeMultiChunkMinimumRunwaySeconds: Double = 0.60
    static let fastModeSingleChunkMinimumCoverageSeconds: Double = 1.8
    static let fastModeMinimumCoverageSeconds: Double = 1.35
    static let fastModeLongFormMinimumCoverageSeconds: Double = 2.4
    static let fastModeUltraLongFormMinimumCoverageSeconds: Double = 3.2
    static let conservativeForegroundRealtimeFactor: Double = 0.88
    static let longFormForegroundRealtimeFactor: Double = 0.80
    static let ultraLongFormForegroundRealtimeFactor: Double = 0.72
    static let returnToHostRunwaySeconds: Double = 6.0
    static let conservativeBackgroundRealtimeFactor: Double = 0.58
    static let remainingWorkSafetyMarginSeconds: Double = 2.5
    static let fastModeRemainingWorkSafetyMarginSeconds: Double = 0.35
    static let fastModeMinimumLeadRatio: Double = 0.10
    static let longFormChunkThreshold = 24
    static let ultraLongFormChunkThreshold = 64
    static let longFormBackgroundRealtimeFactor: Double = 0.52
    static let ultraLongFormBackgroundRealtimeFactor: Double = 0.42
    static let maximumBaseDeterministicRunwaySeconds: Double = 90.0
    static let preparationCompletionDelaySeconds: Double = 0.5

    static func normalModeRequiredStartSampleCount(sampleRate: Double, chunkCount: Int) -> Int {
        let seconds = chunkCount == 1
            ? singleChunkStartBufferedSeconds
            : multiChunkMinimumRunwaySeconds
        return Int(sampleRate * seconds)
    }

    static func fastModeRequiredStartSampleCount(sampleRate: Double, chunkCount: Int) -> Int {
        let seconds = chunkCount == 1
            ? fastModeSingleChunkStartBufferedSeconds
            : fastModeMultiChunkMinimumRunwaySeconds
        return Int(sampleRate * seconds)
    }

    static func normalModeBufferedSampleCount(
        sampleRate: Double,
        chunkCount: Int,
        remainingEstimatedSamples: Int,
        requiredStartSamples: Int,
        minimumCoverageSeconds: Double,
        realtimeFactor: Double,
        remainingWorkSafetyMarginSeconds: Double,
        allowFullRemainingDeficit: Bool
    ) -> Int {
        let minimumCoverageSamples = Int(sampleRate * minimumCoverageSeconds)
        if remainingEstimatedSamples <= minimumCoverageSamples {
            return max(requiredStartSamples, remainingEstimatedSamples)
        }

        let deficitFactor = max(0, (1.0 / realtimeFactor) - 1.0)
        let remainingEstimatedSeconds = Double(remainingEstimatedSamples) / sampleRate
        let uncappedRequiredDeficitSeconds = (remainingEstimatedSeconds * deficitFactor)
            + remainingWorkSafetyMarginSeconds
        let requiredDeficitSeconds: Double
        if allowFullRemainingDeficit {
            requiredDeficitSeconds = min(remainingEstimatedSeconds, uncappedRequiredDeficitSeconds)
        } else if chunkCount > ultraLongFormChunkThreshold,
                  uncappedRequiredDeficitSeconds >= remainingEstimatedSeconds {
            requiredDeficitSeconds = remainingEstimatedSeconds
        } else {
            requiredDeficitSeconds = min(
                maximumDeterministicRunwaySeconds(for: chunkCount),
                uncappedRequiredDeficitSeconds
            )
        }
        let deterministicRunwaySamples = Int(requiredDeficitSeconds * sampleRate)

        return max(
            requiredStartSamples,
            minimumCoverageSamples,
            deterministicRunwaySamples
        )
    }

    static func leadProtectedBufferedSampleCount(
        remainingEstimatedSamples: Int,
        realtimeFactor: Double,
        minimumLeadRatio: Double
    ) -> Int {
        guard remainingEstimatedSamples > 0 else { return 0 }
        let leadProtectionFactor = max(
            0,
            (1.0 - realtimeFactor) + (minimumLeadRatio / max(0.0001, 1.0 - minimumLeadRatio))
        )
        return Int(ceil(Double(remainingEstimatedSamples) * leadProtectionFactor))
    }

    static func fastModeMinimumCoverageSeconds(for chunkCount: Int) -> Double {
        switch chunkCount {
        case (ultraLongFormChunkThreshold + 1)...:
            return fastModeUltraLongFormMinimumCoverageSeconds
        case (longFormChunkThreshold + 1)...:
            return fastModeLongFormMinimumCoverageSeconds
        case 1:
            return fastModeSingleChunkMinimumCoverageSeconds
        default:
            return fastModeMinimumCoverageSeconds
        }
    }

    static func minimumCompletedFastModeSegmentLead(for chunkCount: Int) -> Int {
        switch chunkCount {
        case (ultraLongFormChunkThreshold + 1)...:
            return 3
        case (longFormChunkThreshold + 1)...:
            return 2
        default:
            return 1
        }
    }

    static func backgroundRealtimeFactor(for chunkCount: Int) -> Double {
        switch chunkCount {
        case (ultraLongFormChunkThreshold + 1)...:
            return ultraLongFormBackgroundRealtimeFactor
        case (longFormChunkThreshold + 1)...:
            return longFormBackgroundRealtimeFactor
        default:
            return conservativeBackgroundRealtimeFactor
        }
    }

    static func foregroundRealtimeFactor(for chunkCount: Int) -> Double {
        switch chunkCount {
        case (ultraLongFormChunkThreshold + 1)...:
            return ultraLongFormForegroundRealtimeFactor
        case (longFormChunkThreshold + 1)...:
            return longFormForegroundRealtimeFactor
        default:
            return conservativeForegroundRealtimeFactor
        }
    }

    static func maximumDeterministicRunwaySeconds(for chunkCount: Int) -> Double {
        maximumBaseDeterministicRunwaySeconds
    }
}
