import Foundation
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

    @Test func fastModeStartupLeadRatioScalesByChunkTier() {
        #expect(TTSPlaybackCoordinatorBufferingPolicy.fastModeStartupLeadRatio(for: 8) == 0.10)
        #expect(
            TTSPlaybackCoordinatorBufferingPolicy.fastModeStartupLeadRatio(for: 30)
                == TTSPlaybackCoordinatorBufferingPolicy.fastModeLongFormStartupLeadRatio
        )
        #expect(
            TTSPlaybackCoordinatorBufferingPolicy.fastModeStartupLeadRatio(for: 80)
                == TTSPlaybackCoordinatorBufferingPolicy.fastModeUltraLongFormStartupLeadRatio
        )
    }

    @Test func fastModeStartupLeadRatiosMatchCurrentTunings() {
        #expect(TTSPlaybackCoordinatorBufferingPolicy.fastModeLongFormStartupLeadRatio == 0.28)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.fastModeUltraLongFormStartupLeadRatio == 0.34)
    }

    @Test func deterministicRunwayCapScalesByChunkTier() {
        #expect(TTSPlaybackCoordinatorBufferingPolicy.maximumDeterministicRunwaySeconds(for: 8) == 90.0)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.maximumDeterministicRunwaySeconds(for: 42) == 140.0)
        #expect(TTSPlaybackCoordinatorBufferingPolicy.maximumDeterministicRunwaySeconds(for: 80) == 170.0)
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

    @Test func normalModeStartupBufferedSampleCountUsesCurrentLongFormRunwayCap() {
        let sampleRate = 24_000.0
        let requiredStartSamples = TTSPlaybackCoordinatorBufferingPolicy.normalModeRequiredStartSampleCount(
            sampleRate: sampleRate,
            chunkCount: 42
        )

        let bufferedSampleCount = TTSPlaybackCoordinatorBufferingPolicy.normalModeBufferedSampleCount(
            sampleRate: sampleRate,
            chunkCount: 42,
            remainingEstimatedSamples: 12_000_000,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
            realtimeFactor: TTSPlaybackCoordinatorBufferingPolicy.backgroundRealtimeFactor(for: 42),
            remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: false
        )

        #expect(bufferedSampleCount == Int(sampleRate * 140.0))
    }

    @Test func normalModeStartupBufferedSampleCountUsesFullRemainingRunwayForUltraLongForm() {
        let sampleRate = 24_000.0
        let remainingEstimatedSamples = 4_200_000
        let requiredStartSamples = TTSPlaybackCoordinatorBufferingPolicy.normalModeRequiredStartSampleCount(
            sampleRate: sampleRate,
            chunkCount: 80
        )

        let bufferedSampleCount = TTSPlaybackCoordinatorBufferingPolicy.normalModeBufferedSampleCount(
            sampleRate: sampleRate,
            chunkCount: 80,
            remainingEstimatedSamples: remainingEstimatedSamples,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
            realtimeFactor: TTSPlaybackCoordinatorBufferingPolicy.backgroundRealtimeFactor(for: 80),
            remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: false
        )

        #expect(bufferedSampleCount == remainingEstimatedSamples)
    }

    @Test func fastModeLongFormStartupUsesRaisedLeadRatioInsteadOfCoverageFloorOnly() {
        let sampleRate = 24_000.0
        let remainingEstimatedSamples = 6_533_760
        let bufferedSampleCount = TTSPlaybackCoordinatorBufferingPolicy.fastModeStartupBufferedSampleCount(
            sampleRate: sampleRate,
            chunkCount: 42,
            remainingEstimatedSamples: remainingEstimatedSamples
        )

        #expect(
            bufferedSampleCount
                == Int(
                    ceil(
                        Double(remainingEstimatedSamples)
                            * TTSPlaybackCoordinatorBufferingPolicy.fastModeLongFormStartupLeadRatio
                    )
                )
        )
    }

    @Test func fastModeUltraLongFormStartupUsesCurrentLeadRatioInsteadOfCoverageFloorOnly() {
        let sampleRate = 24_000.0
        let remainingEstimatedSamples = 8_160_000
        let bufferedSampleCount = TTSPlaybackCoordinatorBufferingPolicy.fastModeStartupBufferedSampleCount(
            sampleRate: sampleRate,
            chunkCount: 80,
            remainingEstimatedSamples: remainingEstimatedSamples
        )

        #expect(
            bufferedSampleCount
                == Int(
                    ceil(
                        Double(remainingEstimatedSamples)
                            * TTSPlaybackCoordinatorBufferingPolicy.fastModeUltraLongFormStartupLeadRatio
                    )
                )
        )
    }
}
