import XCTest
@testable import KeyVoxCore
import KeyVoxWhisper

@MainActor
final class WhisperServiceRetryHeuristicsTests: LinguisticAnalyzerTestCase {
    func testTreatsThreeWordResultAsSuspiciousForLongChunk() async {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 3, chunkSeconds: 23.85)

        XCTAssertTrue(suspicious)
    }

    func testDoesNotTreatThreeWordResultAsSuspiciousForShortChunk() async {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 3, chunkSeconds: 2.0)

        XCTAssertFalse(suspicious)
    }

    func testDoesNotTreatNormalWordDensityAsSuspiciousOnLongChunk() async {
        let service = WhisperService()

        let suspicious = service.isSuspiciouslyShortResult(words: 15, chunkSeconds: 20.0)

        XCTAssertFalse(suspicious)
    }

    func testRetriesEmptyResultForLongChunk() async {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 0, chunkSeconds: 16.36)

        XCTAssertTrue(shouldRetry)
    }

    func testDoesNotRetryEmptyResultForShortChunk() async {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 0, chunkSeconds: 2.5)

        XCTAssertFalse(shouldRetry)
    }

    func testDoesNotRetryNonEmptyResultAsEmptyChunk() async {
        let service = WhisperService()

        let shouldRetry = service.shouldRetryEmptyChunkResult(segmentCount: 1, chunkSeconds: 16.36)

        XCTAssertFalse(shouldRetry)
    }

    func testRetriesLowNoSpeechResultWhenTrailingAudioIsUnrepresented() async {
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

    func testDoesNotRetryWhenTrailingAudioIsSilent() async {
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

    func testDoesNotRetryTrailingCutoffWhenDecoderReportsLikelyNoSpeech() async {
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

    func testTrailingCutoffSelectionKeepsSingleRecoveredWord() async {
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

    func testNonTrailingSelectionKeepsExistingTwoWordImprovementThreshold() async {
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
