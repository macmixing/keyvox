import XCTest
@testable import KeyVoxCore
import KeyVoxWhisper

@MainActor
final class WhisperServiceRetryHeuristicsTests: XCTestCase {
    func testTreatsThreeWordResultAsSuspiciousForLongChunk() {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 3, chunkSeconds: 23.85)

        XCTAssertTrue(suspicious)
    }

    func testDoesNotTreatThreeWordResultAsSuspiciousForShortChunk() {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 3, chunkSeconds: 2.0)

        XCTAssertFalse(suspicious)
    }

    func testDoesNotTreatNormalWordDensityAsSuspiciousOnLongChunk() {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 15, chunkSeconds: 20.0)

        XCTAssertFalse(suspicious)
    }

    func testRetriesEmptyResultForLongChunk() {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 0, chunkSeconds: 16.36)

        XCTAssertTrue(shouldRetry)
    }

    func testDoesNotRetryEmptyResultForShortChunk() {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 0, chunkSeconds: 2.5)

        XCTAssertFalse(shouldRetry)
    }

    func testDoesNotRetryNonEmptyResultAsEmptyChunk() {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 1, chunkSeconds: 16.36)

        XCTAssertFalse(shouldRetry)
    }

    func testRetriesLowNoSpeechResultWhenTrailingAudioIsUnrepresented() {
        let service = WhisperService()
        let segments = [
            Segment(
                startTime: 0,
                endTime: 0,
                text: "recognized text",
                noSpeechProbability: service.suspiciousShortResultMaxNoSpeechProbability
            )
        ]

        let shouldRetry = service.shouldRetryTrailingCutoffResult(
            segments: segments,
            chunkSeconds: AudioSilenceGatePolicy.longCaptureMinimumDuration,
            trailingAudioFrames: Self.trailingSpeechFrames()
        )

        XCTAssertTrue(shouldRetry)
    }

    func testDoesNotRetryWhenTrailingAudioIsSilent() {
        let service = WhisperService()
        let segments = [
            Segment(
                startTime: 0,
                endTime: 0,
                text: "recognized text",
                noSpeechProbability: service.suspiciousShortResultMaxNoSpeechProbability
            )
        ]

        let shouldRetry = service.shouldRetryTrailingCutoffResult(
            segments: segments,
            chunkSeconds: AudioSilenceGatePolicy.longCaptureMinimumDuration,
            trailingAudioFrames: Self.trailingSilentFrames()
        )

        XCTAssertFalse(shouldRetry)
    }

    func testDoesNotRetryTrailingCutoffWhenDecoderReportsLikelyNoSpeech() {
        let service = WhisperService()
        let segments = [
            Segment(
                startTime: 0,
                endTime: 0,
                text: "recognized text",
                noSpeechProbability: AudioSilenceGatePolicy.defaultInputVolumeScalar
            )
        ]

        let shouldRetry = service.shouldRetryTrailingCutoffResult(
            segments: segments,
            chunkSeconds: AudioSilenceGatePolicy.longCaptureMinimumDuration,
            trailingAudioFrames: Self.trailingSpeechFrames()
        )

        XCTAssertFalse(shouldRetry)
    }

    func testTrailingCutoffSelectionKeepsSingleRecoveredWord() {
        let service = WhisperService()
        let primary = [
            Segment(startTime: 0, endTime: 100, text: "x")
        ]
        let retry = [
            Segment(startTime: 0, endTime: 100, text: "x y")
        ]

        let selection = service.selectPreferredRetry(
            primary: primary,
            retry: retry,
            acceptsSingleWordRecovery: true
        )

        XCTAssertTrue(selection.selectedRetry)
        XCTAssertEqual(selection.segments.first?.text, retry.first?.text)
    }

    func testNonTrailingSelectionKeepsExistingTwoWordImprovementThreshold() {
        let service = WhisperService()
        let primary = [
            Segment(startTime: 0, endTime: 100, text: "x")
        ]
        let retry = [
            Segment(startTime: 0, endTime: 100, text: "x y")
        ]

        let selection = service.selectPreferredRetry(
            primary: primary,
            retry: retry
        )

        XCTAssertFalse(selection.selectedRetry)
        XCTAssertEqual(selection.segments.first?.text, primary.first?.text)
    }

    private static func trailingSpeechFrames() -> [Float] {
        Array(
            repeating: AudioSilenceGatePolicy.lowConfidenceRMSCutoff,
            count: AudioSilenceGatePolicy.trueSilenceWindowSize
        )
    }

    private static func trailingSilentFrames() -> [Float] {
        Array(
            repeating: Float.zero,
            count: AudioSilenceGatePolicy.trueSilenceWindowSize
        )
    }
}
