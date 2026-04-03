import AVFoundation
import Foundation
import KeyVoxTTS

@MainActor
final class TTSPlaybackCoordinator {
    private enum BufferPolicy {
        static let singleChunkStartBufferedSeconds: Double = 0.45
        static let multiChunkMinimumRunwaySeconds: Double = 1.2
        static let returnToHostRunwaySeconds: Double = 6.0
    }

    var onPlaybackStarted: (() -> Void)?
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackCancelled: (() -> Void)?
    var onPlaybackFailed: ((Error) -> Void)?
    var onPreparationProgress: ((Int, Int, Bool) -> Void)?

    private let audioEngine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let playbackFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 24_000,
        channels: 1,
        interleaved: false
    )!

    private var playbackTask: Task<Void, Never>?
    private var queuedBufferCount = 0
    private var queuedSampleCount = 0
    private var isFinishing = false
    private var didStartPlayback = false
    private var pendingStartBuffers: [AVAudioPCMBuffer] = []
    private var isBackgroundTransitionArmed = false
    private var completedChunkCountBeforeStart = 0
    private var hasBufferedIntoNextChunk = false
    private var activeRequiredStartSampleCount = 0
    private var activeSilentStartSampleCount = 0

    init() {
        audioEngine.attach(playerNode)
        audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: playbackFormat)
    }

    func prepareForForegroundPlayback() {
        isBackgroundTransitionArmed = false
        Self.log("Foreground playback mode armed.")
    }

    func prepareForBackgroundTransition() {
        guard didStartPlayback else {
            isBackgroundTransitionArmed = true
            Self.log("Background transition armed before playback start.")
            return
        }

        isBackgroundTransitionArmed = true
        Self.log(
            "Background transition armed. bufferedSeconds=\(String(format: "%.3f", bufferedSeconds)) queuedBuffers=\(queuedBufferCount)"
        )
    }

    func didEnterBackground() {
        guard isBackgroundTransitionArmed else { return }
        Self.log(
            "Background continuation mode active. bufferedSeconds=\(String(format: "%.3f", bufferedSeconds)) queuedBuffers=\(queuedBufferCount)"
        )
    }

    func play(_ stream: AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>) {
        stop(emitCallback: false)
        Self.log("Playback requested.")

        do {
            try configureAudioSession()
            if audioEngine.isRunning == false {
                try audioEngine.start()
            }
        } catch {
            Self.log("Playback setup failed: \(error.localizedDescription)")
            onPlaybackFailed?(error)
            return
        }

        queuedBufferCount = 0
        queuedSampleCount = 0
        isFinishing = false
        didStartPlayback = false
        pendingStartBuffers = []
        completedChunkCountBeforeStart = 0
        hasBufferedIntoNextChunk = false
        isBackgroundTransitionArmed = false
        activeRequiredStartSampleCount = 0
        activeSilentStartSampleCount = 0

        playbackTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await frame in stream {
                    guard Task.isCancelled == false else { return }
                    await MainActor.run {
                        self.schedule(frame)
                    }
                }

                await MainActor.run {
                    self.isFinishing = true
                    Self.log("Playback stream finished. queuedBuffers=\(self.queuedBufferCount) queuedSamples=\(self.queuedSampleCount)")
                    self.finishIfPossible()
                }
            } catch {
                await MainActor.run {
                    Self.log("Playback stream failed: \(error.localizedDescription)")
                    self.handleFailure(error)
                }
            }
        }
    }

    func stop() {
        stop(emitCallback: true)
    }

    private func stop(emitCallback: Bool) {
        let hadPlayback = playbackTask != nil || playerNode.isPlaying || queuedBufferCount > 0
        Self.log("Stopping playback. hadPlayback=\(hadPlayback) queuedBuffers=\(queuedBufferCount) queuedSamples=\(queuedSampleCount)")

        playbackTask?.cancel()
        playbackTask = nil
        queuedBufferCount = 0
        queuedSampleCount = 0
        isFinishing = false
        didStartPlayback = false
        pendingStartBuffers.removeAll(keepingCapacity: false)
        completedChunkCountBeforeStart = 0
        hasBufferedIntoNextChunk = false
        isBackgroundTransitionArmed = false
        activeRequiredStartSampleCount = 0
        activeSilentStartSampleCount = 0

        if playerNode.isPlaying {
            playerNode.stop()
        }
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])

        if emitCallback, hadPlayback {
            onPlaybackCancelled?()
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    private func schedule(_ frame: KeyVoxTTSAudioFrame) {
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

            let requiredBufferedSamples = requiredStartSampleCount(for: frame.chunkCount)
            activeRequiredStartSampleCount = requiredBufferedSamples
            activeSilentStartSampleCount = silentStartSampleCount(for: frame.chunkCount)
            let requiredBufferedSeconds = Double(requiredBufferedSamples) / playbackFormat.sampleRate
            let hasEnoughBufferedAudio = queuedSampleCount >= activeSilentStartSampleCount
            let hasObservedChunkRunway = frame.chunkCount == 1
                ? hasEnoughBufferedAudio
                : completedChunkCountBeforeStart >= 1 && hasBufferedIntoNextChunk && hasEnoughBufferedAudio
            onPreparationProgress?(
                min(queuedSampleCount, activeSilentStartSampleCount),
                activeSilentStartSampleCount,
                false
            )
            Self.log(
                "Prebuffering chunk=\(frame.chunkIndex + 1)/\(frame.chunkCount) frameIndex=\(frame.frameIndex) queuedSamples=\(queuedSampleCount) requiredSamples=\(requiredBufferedSamples) silentStartSamples=\(activeSilentStartSampleCount) requiredSeconds=\(String(format: "%.3f", requiredBufferedSeconds))"
            )
            if hasObservedChunkRunway || (isLastChunk && frame.isChunkFinalBatch) {
                flushPendingStartBuffers()
            }
            return
        }

        scheduleBuffer(buffer, sampleCount: frame.sampleCount)
    }

    private func makeBuffer(from samples: [Float]) -> AVAudioPCMBuffer? {
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

    private func finishIfPossible() {
        guard isFinishing, queuedBufferCount == 0, pendingStartBuffers.isEmpty else { return }
        Self.log("Playback finished.")

        playbackTask = nil
        if playerNode.isPlaying {
            playerNode.stop()
        }
        audioEngine.stop()
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        onPlaybackFinished?()
    }

    private func handleFailure(_ error: Error) {
        Self.log("Playback failure: \(error.localizedDescription)")
        stop(emitCallback: false)
        onPlaybackFailed?(error)
    }

    private func flushPendingStartBuffers() {
        guard didStartPlayback == false else { return }
        guard !pendingStartBuffers.isEmpty else { return }

        let buffered = pendingStartBuffers
        pendingStartBuffers.removeAll(keepingCapacity: true)
        queuedSampleCount = 0
        let bufferedSamples = buffered.reduce(0) { $0 + Int($1.frameLength) }

        for buffer in buffered {
            scheduleBuffer(buffer, sampleCount: Int(buffer.frameLength))
        }

        didStartPlayback = true
        playerNode.play()
        onPreparationProgress?(activeSilentStartSampleCount, activeSilentStartSampleCount, true)
        Self.log("Playback started with bufferedSamples=\(bufferedSamples) queuedBuffers=\(queuedBufferCount)")
        onPlaybackStarted?()
    }

    private func scheduleBuffer(_ buffer: AVAudioPCMBuffer, sampleCount: Int) {
        queuedBufferCount += 1
        queuedSampleCount += sampleCount
        let queuedSeconds = Double(queuedSampleCount) / playbackFormat.sampleRate
        if queuedBufferCount == 1 || queuedSeconds < 0.25 {
            Self.log(
                "Scheduling buffer sampleCount=\(sampleCount) queuedBuffers=\(queuedBufferCount) queuedSeconds=\(String(format: "%.3f", queuedSeconds))"
            )
        }
        playerNode.scheduleBuffer(buffer) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.queuedBufferCount = max(0, self.queuedBufferCount - 1)
                self.queuedSampleCount = max(0, self.queuedSampleCount - sampleCount)
                let remainingSeconds = Double(self.queuedSampleCount) / self.playbackFormat.sampleRate
                if self.queuedBufferCount == 0 || remainingSeconds < 0.25 {
                    Self.log(
                        "Buffer completed sampleCount=\(sampleCount) remainingBuffers=\(self.queuedBufferCount) remainingSeconds=\(String(format: "%.3f", remainingSeconds))"
                    )
                }
                self.finishIfPossible()
            }
        }
    }

    private var bufferedSeconds: Double {
        Double(queuedSampleCount) / playbackFormat.sampleRate
    }

    private func requiredStartSampleCount(for chunkCount: Int) -> Int {
        let seconds = chunkCount == 1
            ? BufferPolicy.singleChunkStartBufferedSeconds
            : BufferPolicy.multiChunkMinimumRunwaySeconds
        return Int(playbackFormat.sampleRate * seconds)
    }

    private func silentStartSampleCount(for chunkCount: Int) -> Int {
        let returnRunwaySamples = Int(playbackFormat.sampleRate * BufferPolicy.returnToHostRunwaySeconds)
        return max(requiredStartSampleCount(for: chunkCount), returnRunwaySamples)
    }

    private static func log(_ message: String) {
        NSLog("[TTSPlaybackCoordinator] %@", message)
    }
}
