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
}
