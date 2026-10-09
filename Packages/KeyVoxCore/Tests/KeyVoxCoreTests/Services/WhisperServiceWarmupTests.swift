import XCTest
@testable import KeyVoxCore

@MainActor
final class WhisperServiceWarmupTests: LinguisticAnalyzerTestCase {
    func testWarmupLoadsVoiceActivityDetectorOffMainThread() async {
        let detectorLoaded = expectation(description: "voice activity detector factory invoked")
        let service = WhisperService(
            voiceActivityDetectorFactory: {
                XCTAssertFalse(Thread.isMainThread)
                detectorLoaded.fulfill()
                return nil
            }
        )

        service.warmup()

        await fulfillment(of: [detectorLoaded], timeout: 1.0)
    }

    func testPreloadReturnsAfterInFlightLoadCompletes() async {
        let detectorLoaded = expectation(description: "voice activity detector factory invoked once")
        let service = WhisperService(
            voiceActivityDetectorFactory: {
                detectorLoaded.fulfill()
                return nil
            }
        )

        service.warmup()
        await service.preloadIfNeeded()

        await fulfillment(of: [detectorLoaded], timeout: 0)
    }

    func testTranscribeDuringWarmupReusesInFlightLoad() async {
        let detectorLoaded = expectation(description: "voice activity detector factory invoked once")
        let service = WhisperService(
            voiceActivityDetectorFactory: {
                detectorLoaded.fulfill()
                return nil
            }
        )

        service.warmup()
        let result = await withCheckedContinuation { continuation in
            service.transcribe(audioFrames: Array(repeating: 0, count: 16_000)) { result in
                continuation.resume(returning: result)
            }
        }

        await fulfillment(of: [detectorLoaded], timeout: 1.0)
        XCTAssertEqual(result?.text, "")
    }
}
