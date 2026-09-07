import Dispatch
import XCTest
import KeyVoxParakeet
@testable import KeyVoxParakeetNative

final class NativeParakeetBackendTests: XCTestCase {
    func testCancellationDuringLoadSkipsInference() async {
        let loading = expectation(description: "model loading")
        let release = DispatchSemaphore(value: 0)
        let backend = NativeParakeetBackend(makeSession: {
            loading.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
            return Session(transcribe: { XCTFail("Cancelled load must not start inference"); return Self.result })
        })
        let task = Task { try await backend.transcribe(audioFrames: [0], params: .default) }
        await fulfillment(of: [loading], timeout: 5)
        backend.cancelCurrentTranscription()
        release.signal()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? ParakeetError, .cancelled) }
        backend.unload()
    }

    func testUnloadWaitsForNativeCallAndDiscardsResult() async throws {
        let entered = expectation(description: "native entered")
        let closed = expectation(description: "native closed")
        let release = DispatchSemaphore(value: 0)
        let session = Session(transcribe: {
            entered.fulfill()
            XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
            return Self.result
        }, close: { closed.fulfill() })
        let backend = NativeParakeetBackend(makeSession: { session })
        let task = Task { try await backend.transcribe(audioFrames: [0], params: .default) }
        await fulfillment(of: [entered], timeout: 5)
        backend.unload()
        backend.unload()
        XCTAssertEqual(session.closeCount, 0)
        release.signal()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? ParakeetError, .cancelled) }
        await fulfillment(of: [closed], timeout: 5)
        XCTAssertEqual(session.closeCount, 1)
        do { _ = try await backend.transcribe(audioFrames: [0], params: .default); XCTFail("Expected unavailable") }
        catch { XCTAssertEqual(error as? ParakeetError, .runtimeUnavailable) }
    }

    func testCancellationKeepsSessionReusable() async throws {
        let entered = expectation(description: "native entered")
        let release = DispatchSemaphore(value: 0)
        var calls = 0 // Accessed exclusively on the backend worker.
        let session = Session(transcribe: {
            calls += 1
            if calls == 1 {
                entered.fulfill()
                XCTAssertEqual(release.wait(timeout: .now() + 5), .success)
            }
            return Self.result
        })
        let backend = NativeParakeetBackend(makeSession: { session })
        defer { backend.unload() }
        let task = Task { try await backend.transcribe(audioFrames: [0], params: .default) }
        await fulfillment(of: [entered], timeout: 5)
        task.cancel()
        release.signal()
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertEqual(error as? ParakeetError, .cancelled) }
        let result = try await backend.transcribe(audioFrames: [0], params: .default)
        XCTAssertEqual(result, Self.result)
        XCTAssertNil(result.detectedLanguageCode)
        XCTAssertEqual(session.closeCount, 0)
    }

    func testInvalidFramesNeverLoadNativeModel() async {
        let backend = NativeParakeetBackend(makeSession: {
            XCTFail("Invalid input must not load a model")
            throw ParakeetError.initializationFailed
        })
        for frames: [Float] in [[], [.nan], [.infinity], [-.infinity]] {
            do { _ = try await backend.transcribe(audioFrames: frames, params: .default); XCTFail("Expected invalid frames") }
            catch { XCTAssertEqual(error as? ParakeetError, .invalidFrames) }
        }
    }

    func testNativeFailurePropagates() async {
        let backend = NativeParakeetBackend(makeSession: {
            Session(transcribe: { throw ParakeetError.transcriptionFailed(code: -1, message: nil) })
        })
        do { _ = try await backend.transcribe(audioFrames: [0], params: .default); XCTFail("Expected failure") }
        catch { XCTAssertEqual(error as? ParakeetError, .transcriptionFailed(code: -1, message: nil)) }
    }

    private static let result = ParakeetTranscriptionResult(segments: [])
}

private final class Session: NativeParakeetSession {
    let infer: () throws -> ParakeetTranscriptionResult
    let onClose: () -> Void
    private let lock = NSLock()
    private var closes = 0
    var closeCount: Int { lock.lock(); defer { lock.unlock() }; return closes }

    init(transcribe: @escaping () throws -> ParakeetTranscriptionResult, close: @escaping () -> Void = {}) {
        infer = transcribe
        onClose = close
    }
    func transcribe(_ frames: [Float], params: ParakeetParams) throws -> ParakeetTranscriptionResult { try infer() }
    func close() {
        lock.lock(); closes += 1; lock.unlock()
        onClose()
    }
}
