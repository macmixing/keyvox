import XCTest
import KeyVoxSpeechRuntime
@testable import KeyVoxWhisper

final class WhisperInferenceLifecycleTests: XCTestCase {
    func testReplacementWaitsUntilCanceledRequestFinishesReadingResults() async throws {
        let readingResults = expectation(description: "First request reads results")
        let replacementEntered = expectation(description: "Replacement enters native inference")
        let releaseResults = DispatchSemaphore(value: 0)
        defer { releaseResults.signal() }
        let lock = NSLock()
        var calls = 0
        var firstResultsFinished = false
        var overlapped = false
        var runtime = WhisperRuntime.live
        runtime.initFromFileWithParams = { _, _ in OpaquePointer(bitPattern: 1) }
        runtime.freeContext = { _ in }
        runtime.fixedModelLanguageId = { _ in nil }
        runtime.full = { _, _, _, _ in
            let current = lock.withLock {
                calls += 1
                if calls > 1 { overlapped = !firstResultsFinished }
                return calls
            }
            if current == 2 { replacementEntered.fulfill() }
            return 0
        }
        runtime.fullNSegments = { _ in 0 }
        runtime.fullLangId = { _ in
            if lock.withLock({ calls == 1 }) {
                readingResults.fulfill()
                _ = releaseResults.wait(timeout: .now() + 5)
                lock.withLock { firstResultsFinished = true }
            }
            return -1
        }
        let whisper = Whisper(
            fromFileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString),
            runtime: runtime,
            osVersionProvider: { OperatingSystemVersion(majorVersion: 14, minorVersion: 0, patchVersion: 0) },
            inferenceQueue: DispatchQueue.global(qos: .userInitiated)
        )
        let original = Task { try await whisper.transcribe(audioFrames: [0]) }
        await fulfillment(of: [readingResults], timeout: 5)
        original.cancel()
        let replacement = Task { try await whisper.transcribe(audioFrames: [0]) }
        // Give an incorrectly concurrent worker time to enter while result access is blocked.
        try await Task.sleep(nanoseconds: 100_000_000)
        XCTAssertEqual(lock.withLock { calls }, 1)
        releaseResults.signal()
        _ = try await original.value
        _ = try await replacement.value
        await fulfillment(of: [replacementEntered], timeout: 5)
        XCTAssertFalse(lock.withLock { overlapped })
    }
}
