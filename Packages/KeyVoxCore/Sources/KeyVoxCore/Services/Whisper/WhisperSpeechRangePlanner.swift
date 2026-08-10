import Foundation
import KeyVoxWhisper

struct WhisperSpeechRangePlanner: Sendable {
    struct FrameRange: Equatable, Sendable {
        let startFrame: Int
        let endFrame: Int

        var isEmpty: Bool {
            endFrame <= startFrame
        }
    }

    private let sampleRate: Double

    init(sampleRate: Double = 16_000) {
        self.sampleRate = sampleRate
    }

    func ranges(
        for chunk: AudioParagraphChunker.Chunk,
        speechSegments: [WhisperVoiceActivitySegment],
        audioFrameCount: Int
    ) -> [FrameRange] {
        guard audioFrameCount > 0 else { return [] }

        let chunkStartFrame = max(0, min(chunk.startFrame, audioFrameCount))
        let chunkEndFrame = max(chunkStartFrame, min(chunk.endFrame, audioFrameCount))
        guard chunkEndFrame > chunkStartFrame else { return [] }

        let clippedRanges = speechSegments.compactMap { segment -> FrameRange? in
            guard let segmentStartFrame = frameIndex(forCentiseconds: segment.startTime),
                  let segmentEndFrame = frameIndex(forCentiseconds: segment.endTime) else {
                return nil
            }

            let startFrame = max(chunkStartFrame, segmentStartFrame)
            let endFrame = min(chunkEndFrame, segmentEndFrame)
            guard endFrame > startFrame else { return nil }

            return FrameRange(startFrame: startFrame, endFrame: endFrame)
        }

        return mergeOverlappingRanges(clippedRanges)
    }

    func compactedFrames(
        from audioFrames: [Float],
        ranges: [FrameRange],
        maximumInterRangeSilenceMilliseconds: Int
    ) -> [Float] {
        guard !audioFrames.isEmpty else { return [] }

        let validRanges = mergeOverlappingRanges(
            ranges.compactMap { range in
                let startFrame = max(0, min(range.startFrame, audioFrames.count))
                let endFrame = max(startFrame, min(range.endFrame, audioFrames.count))
                let clippedRange = FrameRange(startFrame: startFrame, endFrame: endFrame)
                return clippedRange.isEmpty ? nil : clippedRange
            }
        )
        guard !validRanges.isEmpty else { return [] }

        let maximumInterRangeSilenceFrames = max(
            0,
            Int(
                (Double(maximumInterRangeSilenceMilliseconds) / 1_000.0 * sampleRate)
                    .rounded()
            )
        )
        let totalRangeFrames = validRanges.reduce(0) { $0 + ($1.endFrame - $1.startFrame) }
        let separatorCount = max(0, validRanges.count - 1) * maximumInterRangeSilenceFrames
        var compacted = [Float]()
        compacted.reserveCapacity(totalRangeFrames + separatorCount)

        for (index, range) in validRanges.enumerated() {
            if index > 0 {
                let previousRange = validRanges[index - 1]
                let sourceGapFrames = max(0, range.startFrame - previousRange.endFrame)
                let separatorFrames = min(sourceGapFrames, maximumInterRangeSilenceFrames)
                if separatorFrames > 0 {
                    compacted.append(contentsOf: repeatElement(0, count: separatorFrames))
                }
            }

            compacted.append(contentsOf: audioFrames[range.startFrame..<range.endFrame])
        }

        return compacted
    }

    private func frameIndex(forCentiseconds timeCentiseconds: Float) -> Int? {
        let scaledTime = Double(timeCentiseconds) / 100.0 * sampleRate
        guard timeCentiseconds.isFinite,
              scaledTime.isFinite,
              scaledTime >= 0,
              scaledTime <= Double(Int.max) else {
            return nil
        }

        return Int(scaledTime.rounded())
    }

    private func mergeOverlappingRanges(_ ranges: [FrameRange]) -> [FrameRange] {
        let sortedRanges = ranges
            .filter { !$0.isEmpty }
            .sorted {
                if $0.startFrame == $1.startFrame {
                    return $0.endFrame < $1.endFrame
                }
                return $0.startFrame < $1.startFrame
            }

        var merged: [FrameRange] = []
        merged.reserveCapacity(sortedRanges.count)

        for range in sortedRanges {
            guard let previous = merged.last else {
                merged.append(range)
                continue
            }

            guard range.startFrame <= previous.endFrame else {
                merged.append(range)
                continue
            }

            merged[merged.count - 1] = FrameRange(
                startFrame: previous.startFrame,
                endFrame: max(previous.endFrame, range.endFrame)
            )
        }

        return merged
    }
}
