import XCTest
import KeyVoxWhisper
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

    func testTranscribeDuringWarmupReusesInFlightLoad() async throws {
        let modelURL = try makeModelFile()
        let unloadableModelURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyvox-core-whisper-missing-\(UUID().uuidString).bin")
        let detectorLoaded = expectation(description: "voice activity detector factory invoked once")
        let modelLoaded = expectation(description: "whisper factory invoked once")
        let service = WhisperService(
            modelPathResolver: { modelURL.path },
            voiceActivityDetectorFactory: {
                detectorLoaded.fulfill()
                return nil
            },
            whisperFactory: { _, params in
                modelLoaded.fulfill()
                return Whisper(fromFileURL: unloadableModelURL, withParams: params)
            }
        )

        service.warmup()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            service.transcribe(audioFrames: Array(repeating: 0, count: 16_000)) { _ in
                continuation.resume()
            }
        }

        await fulfillment(of: [detectorLoaded, modelLoaded], timeout: 1.0)
    }

    private func makeModelFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("keyvox-core-whisper-\(UUID().uuidString).bin")
        try Data([0x00]).write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }
}
