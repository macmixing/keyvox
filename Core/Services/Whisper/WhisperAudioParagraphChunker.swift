import Foundation

struct WhisperAudioParagraphChunker {
    private static let sampleRate: Double = 16_000

    struct Chunk {
        let startFrame: Int
        let endFrame: Int
    }

    struct Result {
        let chunks: [Chunk]
        let boundaryFrames: [Int]
        let silenceBoundaryFrames: [Int]
        let fallbackBoundaryFrames: [Int]
        let chunkFrameLengths: [Int]
        let silenceThreshold: Float
        let windowCount: Int
        let maxChunkFrames: Int
    }

    struct Config {
        let windowSize: Int
        let minChunkFrames: Int
        let minSilentWindowsForSplit: Int
        let ambientFloorPercentile: Float
        let minimumSilenceThreshold: Float
        let silenceThresholdMultiplier: Float
        let maxChunkFrames: Int
        let fallbackBoundarySearchRadiusFrames: Int
        let fallbackBoundaryMinDistanceFromEdgesFrames: Int

        init(
            windowSize: Int = 1_600,               // 100ms at 16kHz
            minChunkFrames: Int = 32_000,          // 2s
            minSilentWindowsForSplit: Int = 15,    // 1.5s Silence before paragraph break
            ambientFloorPercentile: Float = 0.20,
            minimumSilenceThreshold: Float = 0.0025,
            silenceThresholdMultiplier: Float = 2.2,
            maxChunkFrames: Int = 384_000,         // 24s at 16kHz
            fallbackBoundarySearchRadiusFrames: Int = 16_000, // 1s at 16kHz
            fallbackBoundaryMinDistanceFromEdgesFrames: Int = 8_000 // 0.5s at 16kHz
        ) {
            self.windowSize = windowSize
            self.minChunkFrames = minChunkFrames
            self.minSilentWindowsForSplit = minSilentWindowsForSplit
            self.ambientFloorPercentile = ambientFloorPercentile
            self.minimumSilenceThreshold = minimumSilenceThreshold
            self.silenceThresholdMultiplier = silenceThresholdMultiplier
            self.maxChunkFrames = maxChunkFrames
            self.fallbackBoundarySearchRadiusFrames = fallbackBoundarySearchRadiusFrames
            self.fallbackBoundaryMinDistanceFromEdgesFrames = fallbackBoundaryMinDistanceFromEdgesFrames
        }
    }

    let config: Config

    init(config: Config = Config()) {
        self.config = config
    }

    func split(_ audioFrames: [Float]) -> Result {
        guard !audioFrames.isEmpty else {
            return Result(
                chunks: [],
                boundaryFrames: [],
                silenceBoundaryFrames: [],
                fallbackBoundaryFrames: [],
                chunkFrameLengths: [],
                silenceThreshold: config.minimumSilenceThreshold,
                windowCount: 0,
                maxChunkFrames: config.maxChunkFrames
            )
        }

        let windowRMS = rmsWindows(from: audioFrames, windowSize: config.windowSize)
        let ambientFloor = percentile(windowRMS, p: config.ambientFloorPercentile) ?? config.minimumSilenceThreshold
        let silenceThreshold = max(config.minimumSilenceThreshold, ambientFloor * config.silenceThresholdMultiplier)

        var silenceBoundaryFrames: [Int] = []
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

            silenceBoundaryFrames.append(boundary)
            chunkStartFrame = boundary
        }

        var fallbackBoundaryFrames: [Int] = []
        var combinedBoundaries: [Int] = []
        var segmentStart = 0
        for silenceBoundary in silenceBoundaryFrames {
            appendFallbackBoundaries(
                from: segmentStart,
                to: silenceBoundary,
                windowRMS: windowRMS,
                audioFrameCount: audioFrames.count,
                into: &fallbackBoundaryFrames,
                combinedBoundaries: &combinedBoundaries
            )
            combinedBoundaries.append(silenceBoundary)
            segmentStart = silenceBoundary
        }
        appendFallbackBoundaries(
            from: segmentStart,
            to: audioFrames.count,
            windowRMS: windowRMS,
            audioFrameCount: audioFrames.count,
            into: &fallbackBoundaryFrames,
            combinedBoundaries: &combinedBoundaries
        )

        let boundaryFrames = combinedBoundaries.sorted()
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

        let chunkFrameLengths = chunks.map { $0.endFrame - $0.startFrame }
        let result = Result(
            chunks: chunks,
            boundaryFrames: boundaryFrames,
            silenceBoundaryFrames: silenceBoundaryFrames,
            fallbackBoundaryFrames: fallbackBoundaryFrames.sorted(),
            chunkFrameLengths: chunkFrameLengths,
            silenceThreshold: silenceThreshold,
            windowCount: windowRMS.count,
            maxChunkFrames: config.maxChunkFrames
        )
        #if DEBUG
        logSplitSummary(result, totalFrames: audioFrames.count)
        #endif
        return result
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

    private func appendFallbackBoundaries(
        from chunkStart: Int,
        to chunkEnd: Int,
        windowRMS: [Float],
        audioFrameCount: Int,
        into fallbackBoundaryFrames: inout [Int],
        combinedBoundaries: inout [Int]
    ) {
        guard chunkEnd > chunkStart else { return }
        guard config.maxChunkFrames > 0 else { return }

        var start = chunkStart
        while chunkEnd - start > config.maxChunkFrames {
            let target = start + config.maxChunkFrames
            let boundary = refinedFallbackBoundary(
                targetFrame: target,
                chunkStart: start,
                chunkEnd: chunkEnd,
                windowRMS: windowRMS,
                audioFrameCount: audioFrameCount
            )
            guard boundary > start, boundary < chunkEnd else { break }
            fallbackBoundaryFrames.append(boundary)
            combinedBoundaries.append(boundary)
            start = boundary
        }
    }

    private func refinedFallbackBoundary(
        targetFrame: Int,
        chunkStart: Int,
        chunkEnd: Int,
        windowRMS: [Float],
        audioFrameCount: Int
    ) -> Int {
        let minEdgeDistance = max(0, config.fallbackBoundaryMinDistanceFromEdgesFrames)
        let lowerBound = max(chunkStart + minEdgeDistance, chunkStart + 1)
        let upperBound = min(chunkEnd - minEdgeDistance, chunkEnd - 1)
        guard lowerBound <= upperBound else {
            return min(max(targetFrame, chunkStart + 1), chunkEnd - 1)
        }

        let maxAllowedBoundary = min(upperBound, targetFrame)
        let clampedTarget = min(max(targetFrame, lowerBound), maxAllowedBoundary)
        let searchRadius = max(0, config.fallbackBoundarySearchRadiusFrames)
        let searchStart = max(lowerBound, clampedTarget - searchRadius)
        let searchEnd = min(maxAllowedBoundary, clampedTarget + searchRadius)

        guard !windowRMS.isEmpty, config.windowSize > 0 else { return clampedTarget }

        let startWindow = max(0, min(windowRMS.count - 1, searchStart / config.windowSize))
        let endWindow = max(0, min(windowRMS.count - 1, searchEnd / config.windowSize))
        guard startWindow <= endWindow else { return clampedTarget }

        let targetWindow = max(0, min(windowRMS.count - 1, clampedTarget / config.windowSize))
        var bestWindow = targetWindow
        var bestRMS = windowRMS[targetWindow]
        var bestDistance = abs(centerFrame(forWindow: targetWindow, audioFrameCount: audioFrameCount) - clampedTarget)

        for windowIndex in startWindow...endWindow {
            let rms = windowRMS[windowIndex]
            let center = centerFrame(forWindow: windowIndex, audioFrameCount: audioFrameCount)
            let distance = abs(center - clampedTarget)
            if rms < bestRMS || (rms == bestRMS && distance < bestDistance) {
                bestWindow = windowIndex
                bestRMS = rms
                bestDistance = distance
            }
        }

        let refined = min(max(centerFrame(forWindow: bestWindow, audioFrameCount: audioFrameCount), lowerBound), upperBound)
        return refined
    }

    private func centerFrame(forWindow windowIndex: Int, audioFrameCount: Int) -> Int {
        let start = windowIndex * config.windowSize
        let end = min(start + config.windowSize, audioFrameCount)
        return start + ((end - start) / 2)
    }

    #if DEBUG
    private func logSplitSummary(_ result: Result, totalFrames: Int) {
        let rawDebugTextLoggingEnabled = ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"
        let loggedText: String
        if rawDebugTextLoggingEnabled {
            let silenceMs = result.silenceBoundaryFrames.map { Int((Double($0) / Self.sampleRate) * 1_000.0) }
            let fallbackMs = result.fallbackBoundaryFrames.map { Int((Double($0) / Self.sampleRate) * 1_000.0) }
            let chunkSeconds = result.chunkFrameLengths.map { String(format: "%.2f", Double($0) / Self.sampleRate) }
            let totalSeconds = Double(totalFrames) / Self.sampleRate
            loggedText =
                "frames=\(totalFrames) " +
                "secs=\(String(format: "%.2f", totalSeconds)) " +
                "windows=\(result.windowCount) " +
                "threshold=\(String(format: "%.5f", result.silenceThreshold)) " +
                "silenceBoundariesMs=\(silenceMs) " +
                "fallbackBoundariesMs=\(fallbackMs) " +
                "chunks=\(result.chunks.count) " +
                "chunkSeconds=\(chunkSeconds)"
        } else {
            loggedText = "<redacted>"
        }

        print("WhisperChunker: \(loggedText)")
    }
    #endif
}
