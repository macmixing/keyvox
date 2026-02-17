import Foundation
import XCTest
@testable import KeyVox

final class WhisperAudioParagraphChunkerTests: XCTestCase {
    func testSplitCreatesBoundaryAtLongSilence() {
        let chunker = WhisperAudioParagraphChunker()
        let audio = makeSpeech(32_000) + makeSilence(24_000) + makeSpeech(32_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.chunks.count, 2)
        XCTAssertEqual(result.boundaryFrames.count, 1)
    }

    func testSplitDoesNotBoundaryAtShortSilence() {
        let chunker = WhisperAudioParagraphChunker()
        let audio = makeSpeech(32_000) + makeSilence(8_000) + makeSpeech(32_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.chunks.count, 1)
        XCTAssertTrue(result.boundaryFrames.isEmpty)
    }

    func testSplitAvoidsTinyTrailingChunk() {
        let chunker = WhisperAudioParagraphChunker()
        let audio = makeSpeech(64_000) + makeSilence(24_000) + makeSpeech(8_000)

        let result = chunker.split(audio)

        XCTAssertEqual(result.chunks.count, 1)
        XCTAssertTrue(result.boundaryFrames.isEmpty)
    }

    func testSplitEmptyInputReturnsNoChunks() {
        let chunker = WhisperAudioParagraphChunker()

        let result = chunker.split([])

        XCTAssertTrue(result.chunks.isEmpty)
        XCTAssertTrue(result.boundaryFrames.isEmpty)
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
