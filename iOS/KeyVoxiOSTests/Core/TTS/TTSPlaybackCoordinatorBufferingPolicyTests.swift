import Testing
@testable import KeyVox_iOS

struct TTSPlaybackCoordinatorBufferingPolicyTests {
    @Test func fastModeCoverageFloorScalesByChunkTier() {
        #expect(TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumCoverageSeconds(for: 1) == 1.8)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumCoverageSeconds(for: 8) == 1.35)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumCoverageSeconds(for: 25) == 2.4)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumCoverageSeconds(for: 65) == 3.2)
    }

    @Test func fastModeSegmentLeadScalesByChunkTier() {
        #expect(TTSPlaybackCoordinatorBufferingPolicy.minimumCompletedFastModeSegmentLead(for: 2) == 1)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.minimumCompletedFastModeSegmentLead(for: 30) == 2)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.minimumCompletedFastModeSegmentLead(for: 80) == 3)
    }

    @Test func normalModeBufferedSampleCountHonorsMinimumCoverageFloor() {
        let sampleRate = 24_000.0
        let requiredStartSamples = TTSPlaybackCoordinatorBufferingPolicy.normalModeRequiredStartSampleCount(
            sampleRate: sampleRate,
            chunkCount: 5
        )

        let bufferedSampleCount = TTSPlaybackCoordinatorBufferingPolicy.normalModeBufferedSampleCount(
            sampleRate: sampleRate,
            chunkCount: 5,
            remainingEstimatedSamples: 480_000,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
            realtimeFactor: TTSPlaybackCoordinatorBufferingPolicy.backgroundRealtimeFactor(for: 5),
            remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: false
        )

        #expect(bufferedSampleCount >= Int(sampleRate * TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds))
    }

    @Test func fastModeBufferedSampleCountUsesLongFormCoverageFloorDeterministically() {
        let sampleRate = 24_000.0
        let requiredStartSamples = TTSPlaybackCoordinatorBufferingPolicy.fastModeRequiredStartSampleCount(
            sampleRate: sampleRate,
            chunkCount: 30
        )

        let bufferedSampleCount = TTSPlaybackCoordinatorBufferingPolicy.normalModeBufferedSampleCount(
            sampleRate: sampleRate,
            chunkCount: 30,
            remainingEstimatedSamples: 120_000,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumCoverageSeconds(for: 30),
            realtimeFactor: TTSPlaybackCoordinatorBufferingPolicy.foregroundRealtimeFactor(for: 30),
            remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.fastModeRemainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: true
        )

        #expect(bufferedSampleCount >= Int(sampleRate * TTSPlaybackCoordinatorBufferingPolicy.fastModeLongFormMinimumCoverageSeconds))
    }

    @Test func longFormForegroundRealtimeFactorMatchesTheMeasuredFastModeEnvelope() {
        #expect(TTSPlaybackCoordinatorBufferingPolicy.foregroundRealtimeFactor(for: 42) == 0.62)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.foregroundRealtimeFactor(for: 80) == 0.56)
    }

    @Test func fastModeBackgroundSafetyRequiresFullThresholdBeforeEnteringSafeState() {
        #expect(
            TTSPlaybackCoordinatorBufferingPolicy.isFastModeBackgroundSafe(
                queuedSampleCount: 9_999,
                requiredSampleCount: 10_000,
                wasSafe: false
            ) == false
        )

        #expect(
            TTSPlaybackCoordinatorBufferingPolicy.isFastModeBackgroundSafe(
                queuedSampleCount: 10_000,
                requiredSampleCount: 10_000,
                wasSafe: false
            ) == true
        )
    }

    @Test func fastModeBackgroundSafetyUsesReleaseHysteresisAfterEnteringSafeState() {
        #expect(
            TTSPlaybackCoordinatorBufferingPolicy.isFastModeBackgroundSafe(
                queuedSampleCount: 9_250,
                requiredSampleCount: 10_000,
                wasSafe: true
            ) == true
        )

        #expect(
            TTSPlaybackCoordinatorBufferingPolicy.isFastModeBackgroundSafe(
                queuedSampleCount: 9_199,
                requiredSampleCount: 10_000,
                wasSafe: true
            ) == false
        )
    }

    @Test func backgroundContinuationSampleCountDoesNotCapLongFormRemainingWorkAtNinetySeconds() {
        let sampleRate = 24_000.0
        let remainingEstimatedSamples = 4_667_520

        let bufferedSampleCount =
            TTSPlaybackCoordinatorBufferingPolicy.deterministicBackgroundContinuationSampleCount(
                sampleRate: sampleRate,
                chunkCount: 42,
                remainingEstimatedSamples: remainingEstimatedSamples,
                minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
                realtimeFactor: TTSPlaybackCoordinatorBufferingPolicy.backgroundRealtimeFactor(for: 42),
                remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
                minimumLeadRatio: TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumLeadRatio
            )

        #expect(bufferedSampleCount > Int(sampleRate * 90.0))
    }

    @Test func backgroundContinuationSampleCountMatchesFullRemainingWorkDeficitForLongForm() {
        let sampleRate = 24_000.0
        let remainingEstimatedSamples = 4_667_520
        let realtimeFactor = TTSPlaybackCoordinatorBufferingPolicy.backgroundRealtimeFactor(for: 42)
        let remainingEstimatedSeconds = Double(remainingEstimatedSamples) / sampleRate
        let expectedRequiredSeconds = min(
            remainingEstimatedSeconds,
            (remainingEstimatedSeconds * ((1.0 / realtimeFactor) - 1.0))
                + TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds
        )

        let bufferedSampleCount =
            TTSPlaybackCoordinatorBufferingPolicy.deterministicBackgroundContinuationSampleCount(
                sampleRate: sampleRate,
                chunkCount: 42,
                remainingEstimatedSamples: remainingEstimatedSamples,
                minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
                realtimeFactor: realtimeFactor,
                remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
                minimumLeadRatio: TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumLeadRatio
            )

        #expect(bufferedSampleCount == Int(expectedRequiredSeconds * sampleRate))
    }

    @Test func fastModeForegroundBufferedSampleCountExceedsTheOldFortyTwoChunkStartupThreshold() {
        let sampleRate = 24_000.0
        let remainingEstimatedSamples = 6_533_760
        let requiredStartSamples = TTSPlaybackCoordinatorBufferingPolicy.fastModeRequiredStartSampleCount(
            sampleRate: sampleRate,
            chunkCount: 42
        )

        let bufferedSampleCount = TTSPlaybackCoordinatorBufferingPolicy.normalModeBufferedSampleCount(
            sampleRate: sampleRate,
            chunkCount: 42,
            remainingEstimatedSamples: remainingEstimatedSamples,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumCoverageSeconds(for: 42),
            realtimeFactor: TTSPlaybackCoordinatorBufferingPolicy.foregroundRealtimeFactor(for: 42),
            remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.fastModeRemainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: true
        )

        #expect(bufferedSampleCount > 2_272_256)
    }
}
