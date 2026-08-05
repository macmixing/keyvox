import XCTest
import KeyVoxWhisper
@testable import KeyVoxCore

final class WhisperSpeechRangePlannerTests: XCTestCase {
    private let planner = WhisperSpeechRangePlanner()

    func testRangesClipSpeechToChunkAndDropSpeechOutsideChunk() {
        let chunk = AudioParagraphChunker.Chunk(
            startFrame: 16_000,
            endFrame: 48_000
        )
        let speechSegments = [
            WhisperVoiceActivitySegment(startTime: 50, endTime: 150),
            WhisperVoiceActivitySegment(startTime: 250, endTime: 350),
            WhisperVoiceActivitySegment(startTime: 400, endTime: 500)
        ]

        let ranges = planner.ranges(
            for: chunk,
            speechSegments: speechSegments,
            audioFrameCount: 64_000
        )

        XCTAssertEqual(
            ranges,
            [
                .init(startFrame: 16_000, endFrame: 24_000),
                .init(startFrame: 40_000, endFrame: 48_000)
            ]
        )
    }

    func testRangesMergeOverlappingSpeechSegments() {
        let chunk = AudioParagraphChunker.Chunk(
            startFrame: 0,
            endFrame: 32_000
        )
        let speechSegments = [
            WhisperVoiceActivitySegment(startTime: 50, endTime: 100),
            WhisperVoiceActivitySegment(startTime: 90, endTime: 150)
        ]

        let ranges = planner.ranges(
            for: chunk,
            speechSegments: speechSegments,
            audioFrameCount: 32_000
        )

        XCTAssertEqual(
            ranges,
            [.init(startFrame: 8_000, endFrame: 24_000)]
        )
    }

    func testCompactedFramesRemoveUnboundedSourceGap() {
        let audioFrames = (0..<6).map(Float.init)
        let ranges = [
            WhisperSpeechRangePlanner.FrameRange(startFrame: 0, endFrame: 2),
            WhisperSpeechRangePlanner.FrameRange(startFrame: 4, endFrame: 6)
        ]

        let compacted = planner.compactedFrames(
            from: audioFrames,
            ranges: ranges,
            maximumInterRangeSilenceMilliseconds: 0
        )

        XCTAssertEqual(compacted, [0, 1, 4, 5])
    }

    func testCompactedFramesPreserveOnlyBoundedInterRangeSilence() {
        let audioFrames = [Float](repeating: 1, count: 4_000)
        let ranges = [
            WhisperSpeechRangePlanner.FrameRange(startFrame: 0, endFrame: 1),
            WhisperSpeechRangePlanner.FrameRange(startFrame: 3_000, endFrame: 3_001)
        ]

        let compacted = planner.compactedFrames(
            from: audioFrames,
            ranges: ranges,
            maximumInterRangeSilenceMilliseconds: 100
        )

        XCTAssertEqual(compacted.count, 1 + 1_600 + 1)
        XCTAssertEqual(compacted.first, 1)
        XCTAssertEqual(compacted.last, 1)
        XCTAssertEqual(compacted.dropFirst().dropLast().allSatisfy { $0 == 0 }, true)
    }

    func testCompactedFramesReturnEmptyForNoSpeechRanges() {
        let compacted = planner.compactedFrames(
            from: [0.1, 0.2],
            ranges: [],
            maximumInterRangeSilenceMilliseconds: 100
        )

        XCTAssertTrue(compacted.isEmpty)
    }
}
