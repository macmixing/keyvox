import AVFoundation
import Foundation
import KeyVoxTTS

extension TTSPlaybackCoordinator {
    func schedule(_ frame: KeyVoxTTSAudioFrame) {
        lastObservedChunkCount = frame.chunkCount
        lastObservedRemainingEstimatedSamples = frame.estimatedRemainingSampleCount
        recordCompletedFastModeSegmentIfNeeded(from: frame)
        updateStreamingPlaybackProgressEstimate(using: frame)

        if frame.samples.isEmpty {
            handleChunkBoundary(frame)
            resumeIfBufferedEnough()
            emitPlaybackProgress()
            notifyFastModeBackgroundSafetyChanged()
            return
        }

        totalGeneratedSampleCount += frame.sampleCount
        activePlaybackSamples.append(contentsOf: frame.samples)
        guard let buffer = makeBuffer(from: frame.samples) else {
            handleFailure(KeyVoxTTSError.inferenceFailure("PocketTTS produced an invalid audio frame."))
            return
        }

        if didStartPlayback == false {
            pendingStartBuffers.append(buffer)
            queuedSampleCount += frame.sampleCount

            let isLastChunk = frame.chunkIndex == frame.chunkCount - 1
            if frame.isChunkFinalBatch {
                completedChunkCountBeforeStart += 1
            } else if frame.chunkIndex > 0 {
                hasBufferedIntoNextChunk = true
            }

            let requiredBufferedSamples = fastModeEnabled
                ? fastModeRequiredStartSampleCount(for: frame.chunkCount)
                : normalModeRequiredStartSampleCount(for: frame.chunkCount)
            activeRequiredStartSampleCount = requiredBufferedSamples
            let silentStartRequirement = fastModeEnabled
                ? deterministicFastModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount
                )
                : normalModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount,
                    requiredStartSamples: requiredBufferedSamples,
                    minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
                    realtimeFactor: backgroundRealtimeFactor(for: frame.chunkCount),
                    remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
                    allowFullRemainingDeficit: false
                )
            activeSilentStartSampleCount = max(activeSilentStartSampleCount, silentStartRequirement)
            let requiredBufferedSeconds = Double(requiredBufferedSamples) / playbackFormat.sampleRate
            let hasEnoughBufferedAudio = queuedSampleCount >= activeSilentStartSampleCount
            let hasObservedChunkRunway = canStartFastModeSegmentedPlayback(
                chunkCount: frame.chunkCount,
                hasEnoughBufferedAudio: hasEnoughBufferedAudio
            )
            onPreparationProgress?(
                min(queuedSampleCount, activeSilentStartSampleCount),
                activeSilentStartSampleCount,
                false
            )
            Self.log(
                "Prebuffering chunk=\(frame.chunkIndex + 1)/\(frame.chunkCount) chunkID=\(frame.chunkDebugID) frameIndex=\(frame.frameIndex) queuedSamples=\(queuedSampleCount) requiredSamples=\(requiredBufferedSamples) silentStartSamples=\(activeSilentStartSampleCount) remainingEstimatedSamples=\(frame.estimatedRemainingSampleCount) requiredSeconds=\(String(format: "%.3f", requiredBufferedSeconds))"
            )
            if hasObservedChunkRunway || (isLastChunk && frame.isChunkFinalBatch) {
                flushPendingStartBuffers()
            }
            return
        }

        scheduleBuffer(buffer, samples: frame.samples, chunkDebugID: frame.chunkDebugID, chunkIndex: frame.chunkIndex)
        resumeIfBufferedEnough()
        emitPlaybackProgress()
        notifyFastModeBackgroundSafetyChanged()
    }

    func updateStreamingPlaybackProgressEstimate(using frame: KeyVoxTTSAudioFrame) {
        let observedTotalSampleCount = totalGeneratedSampleCount + frame.sampleCount + frame.estimatedRemainingSampleCount
        let minimumStableSampleCount = max(totalScheduledSampleCount, currentPlaybackSampleOffset)

        guard totalEstimatedPlaybackSampleCount > 0 else {
            totalEstimatedPlaybackSampleCount = max(observedTotalSampleCount, minimumStableSampleCount)
            return
        }

        if didStartPlayback {
            totalEstimatedPlaybackSampleCount = max(
                minimumStableSampleCount,
                min(totalEstimatedPlaybackSampleCount, observedTotalSampleCount)
            )
        } else {
            totalEstimatedPlaybackSampleCount = max(observedTotalSampleCount, minimumStableSampleCount)
        }
    }

    func handleChunkBoundary(_ frame: KeyVoxTTSAudioFrame) {
        let isLastChunk = frame.chunkIndex == frame.chunkCount - 1

        if didStartPlayback == false {
            if frame.isChunkFinalBatch {
                completedChunkCountBeforeStart += 1
            } else if frame.chunkIndex > 0 {
                hasBufferedIntoNextChunk = true
            }

            let requiredBufferedSamples = fastModeEnabled
                ? fastModeRequiredStartSampleCount(for: frame.chunkCount)
                : normalModeRequiredStartSampleCount(for: frame.chunkCount)
            activeRequiredStartSampleCount = requiredBufferedSamples
            let silentStartRequirement = fastModeEnabled
                ? deterministicFastModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount
                )
                : normalModeBufferedSampleCount(
                    for: frame.chunkCount,
                    remainingEstimatedSamples: frame.estimatedRemainingSampleCount,
                    requiredStartSamples: requiredBufferedSamples,
                    minimumCoverageSeconds: TTSPlaybackCoordinatorBufferingPolicy.returnToHostRunwaySeconds,
                    realtimeFactor: backgroundRealtimeFactor(for: frame.chunkCount),
                    remainingWorkSafetyMarginSeconds: TTSPlaybackCoordinatorBufferingPolicy.remainingWorkSafetyMarginSeconds,
                    allowFullRemainingDeficit: false
                )
            activeSilentStartSampleCount = max(activeSilentStartSampleCount, silentStartRequirement)
            let requiredBufferedSeconds = Double(requiredBufferedSamples) / playbackFormat.sampleRate
            let hasEnoughBufferedAudio = queuedSampleCount >= activeSilentStartSampleCount
            let hasObservedChunkRunway = canStartFastModeSegmentedPlayback(
                chunkCount: frame.chunkCount,
                hasEnoughBufferedAudio: hasEnoughBufferedAudio
            )
            onPreparationProgress?(
                min(queuedSampleCount, activeSilentStartSampleCount),
                activeSilentStartSampleCount,
                false
            )
            Self.log(
                "Prebuffering chunk=\(frame.chunkIndex + 1)/\(frame.chunkCount) chunkID=\(frame.chunkDebugID) frameIndex=\(frame.frameIndex) queuedSamples=\(queuedSampleCount) requiredSamples=\(requiredBufferedSamples) silentStartSamples=\(activeSilentStartSampleCount) remainingEstimatedSamples=\(frame.estimatedRemainingSampleCount) requiredSeconds=\(String(format: "%.3f", requiredBufferedSeconds))"
            )
            if hasObservedChunkRunway || (isLastChunk && frame.isChunkFinalBatch) {
                flushPendingStartBuffers()
            }
        }
    }

    func makeBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: playbackFormat,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else {
            return nil
        }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        guard let channel = buffer.floatChannelData?.pointee else {
            return nil
        }

        samples.withUnsafeBufferPointer { source in
            guard let baseAddress = source.baseAddress else { return }
            channel.update(from: baseAddress, count: samples.count)
        }
        return buffer
    }

    func flushPendingStartBuffers() {
        guard didStartPlayback == false else { return }
        guard !pendingStartBuffers.isEmpty else { return }

        let buffered = pendingStartBuffers
        pendingStartBuffers.removeAll(keepingCapacity: true)
        queuedSampleCount = 0
        let bufferedSamples = buffered.reduce(0) { $0 + Int($1.frameLength) }
        var startDelay: TimeInterval = 0

        for buffer in buffered {
            let samples = copySamples(from: buffer)
            scheduleBuffer(
                buffer,
                samples: samples,
                chunkDebugID: "startup-buffer",
                chunkIndex: nil,
                startDelay: startDelay
            )
            startDelay += TimeInterval(buffer.frameLength) / playbackFormat.sampleRate
        }

        didStartPlayback = true
        onPreparationProgress?(activeSilentStartSampleCount, activeSilentStartSampleCount, false)
        onPreparationCompleted?()
        notifyFastModeBackgroundSafetyChanged()

        let startPlayback = { [weak self] in
            guard let self else { return }
            do {
                try self.ensureAudioEngineReadyForPlayback(context: "startupBuffer")
            } catch {
                self.handleFailure(error)
                return
            }
            self.playerNode.play()
            self.startPlaybackProgressTimer()
            self.onPreparationProgress?(self.activeSilentStartSampleCount, self.activeSilentStartSampleCount, true)
            Self.log("Playback started with bufferedSamples=\(bufferedSamples) queuedBuffers=\(self.queuedBufferCount)")
            self.emitPlaybackProgress()
            self.notifyFastModeBackgroundSafetyChanged()
            self.onPlaybackStarted?()
        }

        if preparationCompletionDelaySeconds > 0 {
            Self.log(
                "Preparation reached 100%; delaying playback start by \(String(format: "%.3f", preparationCompletionDelaySeconds))s"
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + preparationCompletionDelaySeconds) {
                startPlayback()
            }
        } else {
            startPlayback()
        }
    }

    func scheduleBuffer(
        _ buffer: AVAudioPCMBuffer,
        samples: [Float],
        chunkDebugID: String,
        chunkIndex: Int?,
        startDelay: TimeInterval? = nil
    ) {
        let sessionID = playbackSessionID
        let sampleCount = Int(buffer.frameLength)
        let bufferStartDelay = startDelay ?? (Double(queuedSampleCount) / playbackFormat.sampleRate)
        queuedBufferCount += 1
        queuedSampleCount += sampleCount
        totalScheduledSampleCount += sampleCount
        scheduleMeterUpdates(for: samples, startDelay: bufferStartDelay)
        let queuedSeconds = Double(queuedSampleCount) / playbackFormat.sampleRate
        if queuedBufferCount == 1 || queuedSeconds < 0.25 {
            Self.log(
                "Scheduling buffer chunk=\(chunkIndex.map { String($0 + 1) } ?? "-") chunkID=\(chunkDebugID) sampleCount=\(sampleCount) queuedBuffers=\(queuedBufferCount) queuedSeconds=\(String(format: "%.3f", queuedSeconds))"
            )
        }
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard self.playbackSessionID == sessionID else { return }
                self.queuedBufferCount = max(0, self.queuedBufferCount - 1)
                self.queuedSampleCount = max(0, self.queuedSampleCount - sampleCount)
                let remainingSeconds = Double(self.queuedSampleCount) / self.playbackFormat.sampleRate
                if self.queuedBufferCount == 0 || remainingSeconds < 0.25 {
                    Self.log(
                        "Buffer completed chunk=\(chunkIndex.map { String($0 + 1) } ?? "-") chunkID=\(chunkDebugID) sampleCount=\(sampleCount) remainingBuffers=\(self.queuedBufferCount) remainingSeconds=\(String(format: "%.3f", remainingSeconds))"
                    )
                }
                self.emitPlaybackProgress()
                self.notifyFastModeBackgroundSafetyChanged()
                self.finishIfPossible()
            }
        }
    }
}
