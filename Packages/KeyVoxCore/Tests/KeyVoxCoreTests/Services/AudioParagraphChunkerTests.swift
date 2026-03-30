import Foundation
import XCTest
@testable import KeyVoxCore

final class AudioParagraphChunkerTests: XCTestCase {
    func testSplitCreatesBoundaryAtLongSilence() {
        let chunker = AudioParagraphChunker()
        let audio = makeSpeech(32_000) + makeSilence(24_000) + makeSpeech(32_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.chunks.count, 2)
        XCTAssertEqual(result.boundaryFrames.count, 1)
        XCTAssertEqual(result.silenceBoundaryFrames.count, 1)
        XCTAssertTrue(result.fallbackBoundaryFrames.isEmpty)
    }

    func testSplitDoesNotCreateBoundaryAtShortSilence() {
        let chunker = AudioParagraphChunker()
        let audio = makeSpeech(32_000) + makeSilence(8_000) + makeSpeech(32_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.chunks.count, 1)
        XCTAssertTrue(result.boundaryFrames.isEmpty)
    }

    func testSplitAvoidsTinyTrailingChunk() {
        let chunker = AudioParagraphChunker()
        let audio = makeSpeech(64_000) + makeSilence(24_000) + makeSpeech(8_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.chunks.count, 1)
        XCTAssertTrue(result.boundaryFrames.isEmpty)
    }

    func testSplitEmptyInputReturnsNoChunks() {
        let chunker = AudioParagraphChunker()

        let result = chunker.split([])

        XCTAssertTrue(result.chunks.isEmpty)
        XCTAssertTrue(result.boundaryFrames.isEmpty)
    }

    func testSplitsLongContinuousAudioByMaxChunkFallback() {
        let chunker = makeFallbackTestChunker()
        let audio = makeSpeech(170_000)

        let result = chunker.split(audio)

        XCTAssertGreaterThan(result.chunks.count, 1)
        XCTAssertTrue(result.silenceBoundaryFrames.isEmpty)
        XCTAssertGreaterThan(result.fallbackBoundaryFrames.count, 0)
        XCTAssertTrue(result.chunkFrameLengths.allSatisfy { $0 <= result.maxChunkFrames })
    }

    func testPrefersSilenceBoundaryWhenEligible() {
        let chunker = makeFallbackTestChunker()
        let audio = makeSpeech(48_000) + makeSilence(32_000) + makeSpeech(48_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.silenceBoundaryFrames.count, 1)
        XCTAssertTrue(result.fallbackBoundaryFrames.isEmpty)
        XCTAssertEqual(result.boundaryFrames, result.silenceBoundaryFrames)
    }

    func testConversationalPausePatternFallsBackWhenNoSilenceRunQualifies() {
        let chunker = makeFallbackTestChunker()
        var audio: [Float] = []
        for _ in 0..<12 {
            audio += makeSpeech(16_000)
            audio += makeSilence(4_800) // 0.3s, below silence split requirement
        }

        let result = chunker.split(audio)

        XCTAssertTrue(result.silenceBoundaryFrames.isEmpty)
        XCTAssertGreaterThan(result.fallbackBoundaryFrames.count, 0)
        XCTAssertGreaterThan(result.chunks.count, 1)
        XCTAssertTrue(result.chunkFrameLengths.allSatisfy { $0 <= result.maxChunkFrames })
    }

    func testShortAudioRemainsSingleChunk() {
        let chunker = makeFallbackTestChunker()
        let audio = makeSpeech(24_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.chunks.count, 1)
        XCTAssertTrue(result.boundaryFrames.isEmpty)
        XCTAssertTrue(result.silenceBoundaryFrames.isEmpty)
        XCTAssertTrue(result.fallbackBoundaryFrames.isEmpty)
    }

    private func makeFallbackTestChunker() -> AudioParagraphChunker {
        AudioParagraphChunker(
            config: .init(
                maxChunkFrames: 64_000,
                fallbackBoundarySearchRadiusFrames: 8_000,
                fallbackBoundaryMinDistanceFromEdgesFrames: 4_000
            )
        )
    }

    private func makeSpeech(_ frameCount: Int, amplitude: Float = 0.04) -> [Float] {
        guard frameCount > 0 else { return [] }
        return (0..<frameCount).map { index in
            sin(Float(index) * 0.05) * amplitude
        }
    }

    private func makeSilence(_ frameCount: Int) -> [Float] {
        [Float](repeating: 0, count: frameCount)
    }
}
