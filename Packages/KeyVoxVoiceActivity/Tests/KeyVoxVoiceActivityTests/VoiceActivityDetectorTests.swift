import XCTest
@testable import KeyVoxVoiceActivity

final class VoiceActivityDetectorTests: XCTestCase {
    func testSilentAudioContainsNoSpeech() async throws {
        let detector = try XCTUnwrap(VoiceActivityDetector())

        let analysis = await detector.analyze(
            audioFrames: Array(repeating: 0, count: 16_000)
        )

        XCTAssertNotNil(analysis)
        XCTAssertFalse(analysis?.containsSpeech ?? true)
        XCTAssertEqual(analysis?.speechSegments, [])
    }
}
