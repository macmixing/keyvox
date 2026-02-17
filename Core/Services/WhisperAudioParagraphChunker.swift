import Foundation

struct WhisperAudioParagraphChunker {
    struct Chunk {
        let startFrame: Int
        let endFrame: Int
    }

    struct Result {
        let chunks: [Chunk]
        let boundaryFrames: [Int]
        let silenceThreshold: Float
    }

    struct Config {
        let windowSize: Int
        let minChunkFrames: Int
        let minSilentWindowsForSplit: Int
        let ambientFloorPercentile: Float
        let minimumSilenceThreshold: Float
        let silenceThresholdMultiplier: Float

        init(
            windowSize: Int = 1_600,               // 100ms at 16kHz
            minChunkFrames: Int = 32_000,          // 2s
            minSilentWindowsForSplit: Int = 15,    // 1.5s Silence before paragraph break
            ambientFloorPercentile: Float = 0.20,
            minimumSilenceThreshold: Float = 0.0025,
            silenceThresholdMultiplier: Float = 2.2
        ) {
            self.windowSize = windowSize
            self.minChunkFrames = minChunkFrames
            self.minSilentWindowsForSplit = minSilentWindowsForSplit
            self.ambientFloorPercentile = ambientFloorPercentile
            self.minimumSilenceThreshold = minimumSilenceThreshold
            self.silenceThresholdMultiplier = silenceThresholdMultiplier
        }
    }

    private let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    func split(_ audioFrames: [Float]) -> Result {
        guard !audioFrames.isEmpty else {
            return Result(chunks: [], boundaryFrames: [], silenceThreshold: config.minimumSilenceThreshold)
        }

        let windowRMS = rmsWindows(from: audioFrames, windowSize: config.windowSize)
        let ambientFloor = percentile(windowRMS, p: config.ambientFloorPercentile) ?? config.minimumSilenceThreshold
        let silenceThreshold = max(config.minimumSilenceThreshold, ambientFloor * config.silenceThresholdMultiplier)

        var boundaryFrames: [Int] = []
        var chunkStartFrame = 0
        var silentRunStartWindow: Int?

        for windowIndex in 0..<windowRMS.count {
            let isSilent = windowRMS[windowIndex] <= silenceThreshold
            if isSilent {
                if silentRunStartWindow == nil {
                    silentRunStartWindow = windowIndex
                }
                continue
            }

            guard let runStart = silentRunStartWindow else { continue }
            let runLength = windowIndex - runStart
            silentRunStartWindow = nil

            guard runLength >= config.minSilentWindowsForSplit else { continue }

            let runStartFrame = runStart * config.windowSize
            let runEndFrame = min(windowIndex * config.windowSize, audioFrames.count)
            let boundary = runStartFrame + ((runEndFrame - runStartFrame) / 2)

            guard boundary - chunkStartFrame >= config.minChunkFrames else { continue }
            guard audioFrames.count - boundary >= config.minChunkFrames else { continue }

            boundaryFrames.append(boundary)
            chunkStartFrame = boundary
        }

        var chunks: [Chunk] = []
        var startFrame = 0
        for boundary in boundaryFrames {
            if boundary > startFrame {
                chunks.append(Chunk(startFrame: startFrame, endFrame: boundary))
            }
            startFrame = boundary
        }
        if startFrame < audioFrames.count {
            chunks.append(Chunk(startFrame: startFrame, endFrame: audioFrames.count))
        }

        if chunks.isEmpty {
            chunks = [Chunk(startFrame: 0, endFrame: audioFrames.count)]
        }

        return Result(chunks: chunks, boundaryFrames: boundaryFrames, silenceThreshold: silenceThreshold)
    }

    private func rmsWindows(from samples: [Float], windowSize: Int) -> [Float] {
        guard !samples.isEmpty else { return [] }

        var result: [Float] = []
        result.reserveCapacity((samples.count / windowSize) + 1)

        var frameStart = 0
        while frameStart < samples.count {
            let frameEnd = min(frameStart + windowSize, samples.count)
            let window = samples[frameStart..<frameEnd]
            var sumSquares: Float = 0
            for sample in window {
                sumSquares += sample * sample
            }
            let rms = sqrt(sumSquares / Float(window.count))
            result.append(rms)
            frameStart += windowSize
        }

        return result
    }

    private func percentile(_ values: [Float], p: Float) -> Float? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let clampedP = max(0, min(1, p))
        let index = Int(Float(sorted.count - 1) * clampedP)
        return sorted[index]
    }
}
