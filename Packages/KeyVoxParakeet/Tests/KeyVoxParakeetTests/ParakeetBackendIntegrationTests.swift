import Foundation
import XCTest
import KeyVoxParakeet

final class ParakeetBackendIntegrationTests: XCTestCase {
    func testExternalBackendReceivesAudioAndUnload() async throws {
        let model = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data().write(to: model)
        defer { try? FileManager.default.removeItem(at: model) }
        let backend = RecordingBackend()
        let parakeet = try Parakeet(fromModelURL: model, backendFactory: { url in
            XCTAssertEqual(url, model)
            return backend
        })
        let frames: [Float] = [0.25, -0.25]
        let result = try await parakeet.transcribeWithMetadata(audioFrames: frames)
        XCTAssertEqual(backend.frames, frames)
        XCTAssertEqual(result, backend.result)
        parakeet.unload()
        XCTAssertTrue(backend.didUnload)
        do {
            _ = try await parakeet.transcribe(audioFrames: frames)
            XCTFail("Expected unavailable runtime after unload")
        } catch {
            XCTAssertEqual(error as? ParakeetError, .runtimeUnavailable)
        }
    }

    #if !canImport(CoreML)
    func testDefaultBackendReportsUnavailableForModelDirectory() throws {
        let model = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: model, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: model) }
        XCTAssertThrowsError(try Parakeet(fromModelURL: model)) {
            XCTAssertEqual($0 as? ParakeetError, .runtimeUnavailable)
        }
    }
    #endif
}

private final class RecordingBackend: ParakeetRuntimeBackend {
    var frames: [Float] = []
    var didUnload = false
    let result = ParakeetTranscriptionResult(segments: [])

    func transcribe(audioFrames: [Float], params: ParakeetParams) async throws -> ParakeetTranscriptionResult {
        frames = audioFrames
        return result
    }

    func cancelCurrentTranscription() {}
    func unload() { didUnload = true }
}
