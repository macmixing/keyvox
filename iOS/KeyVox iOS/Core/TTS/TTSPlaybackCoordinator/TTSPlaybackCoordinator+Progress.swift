import AVFoundation
import Foundation
import KeyVoxTTS

extension TTSPlaybackCoordinator {
    func currentReplaySampleOffset() -> Int {
        guard isReplayingCachedAudio else { return 0 }
        guard let renderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: renderTime) else {
            return replayPausedSampleOffset
        }

        let currentOffset = replayStartSampleOffset + Int(playerTime.sampleTime)
        return min(max(0, currentOffset), replayablePlaybackSamples.count)
    }

    var bufferedSeconds: Double {
        Double(queuedSampleCount) / playbackFormat.sampleRate
    }

    func recordCompletedFastModeSegmentIfNeeded(from frame: KeyVoxTTSAudioFrame) {
        guard fastModeEnabled, frame.isChunkFinalBatch else { return }
        guard let chunkGeneratedSampleCount = frame.chunkGeneratedSampleCount,
              chunkGeneratedSampleCount > 0 else {
            return
        }

        completedFastModeSegmentCount += 1
    }

    func canStartFastModeSegmentedPlayback(chunkCount: Int, hasEnoughBufferedAudio: Bool) -> Bool {
        guard hasEnoughBufferedAudio else { return false }
        guard fastModeEnabled, chunkCount > 1 else {
            return chunkCount == 1
                ? hasEnoughBufferedAudio
                : completedChunkCountBeforeStart >= 1 && hasBufferedIntoNextChunk && hasEnoughBufferedAudio
        }

        let requiredCompletedSegments = minimumCompletedFastModeSegmentLead(for: chunkCount)

        return completedFastModeSegmentCount >= requiredCompletedSegments
            && completedChunkCountBeforeStart >= requiredCompletedSegments
            && hasBufferedIntoNextChunk
    }

    func shouldDelayResumeUntilBuffered() -> Bool {
        guard fastModeEnabled, !isReplayingCachedAudio else { return false }
        return queuedSampleCount < deterministicFastModeBufferedSampleCount(
            for: lastObservedChunkCount,
            remainingEstimatedSamples: lastObservedRemainingEstimatedSamples
        )
    }

    func resumeIfBufferedEnough() {
        guard isWaitingForResumeBuffer else { return }
        let requiredSamples = deterministicFastModeBufferedSampleCount(
            for: lastObservedChunkCount,
            remainingEstimatedSamples: lastObservedRemainingEstimatedSamples
        )
        guard queuedSampleCount >= requiredSamples || (isFinishing && queuedSampleCount > 0) else { return }

        playerNode.play()
        isPaused = false
        isWaitingForResumeBuffer = false
        if isReplayingCachedAudio {
            replayPausedSampleOffset = 0
        }
        startPlaybackProgressTimer()
        emitPlaybackProgress()
        Self.log(
            "Playback resumed after buffer refill. queuedSeconds=\(String(format: "%.3f", bufferedSeconds)) requiredSeconds=\(String(format: "%.3f", Double(requiredSamples) / playbackFormat.sampleRate)) generatedSeconds=\(String(format: "%.3f", Double(totalGeneratedSampleCount) / playbackFormat.sampleRate))"
        )
        notifyFastModeBackgroundSafetyChanged()
        onPlaybackResumed?()
    }

    func startPlaybackProgressTimer() {
        guard playbackProgressDisplayLink == nil else { return }
        let displayLink = CADisplayLink(target: self, selector: #selector(handlePlaybackProgressDisplayLinkTick))
        if #available(iOS 15.0, *) {
            displayLink.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        } else {
            displayLink.preferredFramesPerSecond = 60
        }
        playbackProgressDisplayLink = displayLink
        displayLink.add(to: .main, forMode: .common)
    }

    func stopPlaybackProgressTimer() {
        playbackProgressDisplayLink?.invalidate()
        playbackProgressDisplayLink = nil
    }

    @objc
    func handlePlaybackProgressDisplayLinkTick() {
        emitPlaybackProgress()
    }

    func emitPlaybackProgress(_ overrideProgress: Double? = nil) {
        let progress = overrideProgress ?? currentPlaybackProgress
        onPlaybackProgressChanged?(min(1, max(0, progress)))
    }

    var currentPlaybackProgress: Double {
        let denominator = currentPlaybackProgressDenominator
        guard denominator > 0 else { return 0 }
        return Double(currentPlaybackSampleOffset) / Double(denominator)
    }

    var currentPlaybackProgressDenominator: Int {
        if isReplayingCachedAudio {
            return replayablePlaybackSamples.count
        }
        return max(totalEstimatedPlaybackSampleCount, totalScheduledSampleCount)
    }

    var currentPlaybackSampleOffset: Int {
        if isReplayingCachedAudio {
            return currentReplaySampleOffset()
        }
        guard let renderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: renderTime) else {
            let playedSamples = max(0, totalScheduledSampleCount - queuedSampleCount)
            return min(playedSamples, currentPlaybackProgressDenominator)
        }
        let playedSamples = max(0, Int(playerTime.sampleTime))
        return min(playedSamples, currentPlaybackProgressDenominator)
    }

    func notifyFastModeBackgroundSafetyChanged() {
        onFastModeBackgroundSafetyChanged?(
            fastModeBackgroundSafetyProgress,
            canContinueBackgroundPlaybackInFastMode
        )
    }

    func deterministicFastModeBufferedSampleCount(for chunkCount: Int, remainingEstimatedSamples: Int) -> Int {
        let requiredStartSamples = fastModeRequiredStartSampleCount(for: chunkCount)
        let deterministicRunwaySamples = normalModeBufferedSampleCount(
            for: chunkCount,
            remainingEstimatedSamples: remainingEstimatedSamples,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: fastModeMinimumCoverageSeconds(for: chunkCount),
            realtimeFactor: foregroundRealtimeFactor(for: chunkCount),
            remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.fastModeRemainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: true
        )
        let leadProtectedSamples = TTSPlaybackCoordinatorBufferingPolicy.leadProtectedBufferedSampleCount(
            remainingEstimatedSamples: remainingEstimatedSamples,
            realtimeFactor: foregroundRealtimeFactor(for: chunkCount),
            minimumLeadRatio: TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumLeadRatio
        )
        return max(deterministicRunwaySamples, leadProtectedSamples)
    }

    func backgroundContinuationBufferedSampleCount(for chunkCount: Int, remainingEstimatedSamples: Int) -> Int {
        normalModeBufferedSampleCount(
            for: chunkCount,
            remainingEstimatedSamples: remainingEstimatedSamples,
            requiredStartSamples: normalModeRequiredStartSampleCount(for: chunkCount),
            minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
            realtimeFactor: backgroundRealtimeFactor(for: chunkCount),
            remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: false
        )
    }

    func normalModeRequiredStartSampleCount(for chunkCount: Int) -> Int {
        TTSPlaybackCoordinatorBufferingPolicy.normalModeRequiredStartSampleCount(
            sampleRate: playbackFormat.sampleRate,
            chunkCount: chunkCount
        )
    }

    func fastModeRequiredStartSampleCount(for chunkCount: Int) -> Int {
        TTSPlaybackCoordinatorBufferingPolicy.fastModeRequiredStartSampleCount(
            sampleRate: playbackFormat.sampleRate,
            chunkCount: chunkCount
        )
    }

    func normalModeBufferedSampleCount(
        for chunkCount: Int,
        remainingEstimatedSamples: Int,
        requiredStartSamples: Int,
        minimumCoverageSeconds: Double,
        realtimeFactor: Double,
        remainingWorkSafetyMarginSeconds: Double,
        allowFullRemainingDeficit: Bool
    ) -> Int {
        TTSPlaybackCoordinatorBufferingPolicy.normalModeBufferedSampleCount(
            sampleRate: playbackFormat.sampleRate,
            chunkCount: chunkCount,
            remainingEstimatedSamples: remainingEstimatedSamples,
            requiredStartSamples: requiredStartSamples,
            minimumCoverageSeconds: minimumCoverageSeconds,
            realtimeFactor: realtimeFactor,
            remainingWorkSafetyMarginSeconds: remainingWorkSafetyMarginSeconds,
            allowFullRemainingDeficit: allowFullRemainingDeficit
        )
    }

    func fastModeMinimumCoverageSeconds(for chunkCount: Int) -> Double {
        TTSPlaybackCoordinatorBufferingPolicy.fastModeMinimumCoverageSeconds(for: chunkCount)
    }

    func minimumCompletedFastModeSegmentLead(for chunkCount: Int) -> Int {
        TTSPlaybackCoordinatorBufferingPolicy.minimumCompletedFastModeSegmentLead(for: chunkCount)
    }

    func backgroundRealtimeFactor(for chunkCount: Int) -> Double {
        TTSPlaybackCoordinatorBufferingPolicy.backgroundRealtimeFactor(for: chunkCount)
    }

    func foregroundRealtimeFactor(for chunkCount: Int) -> Double {
        TTSPlaybackCoordinatorBufferingPolicy.foregroundRealtimeFactor(for: chunkCount)
    }
}
