import Foundation
import XCTest
@testable import KeyVoxWhisper

final class WhisperCoreTests: XCTestCase {
    func testWhisperErrorDescriptions() {
        XCTAssertEqual(WhisperError.initializationFailed.errorDescription, "Failed to initialize Whisper context")
        XCTAssertEqual(WhisperError.invalidFrames.errorDescription, "Audio frames are empty")
        XCTAssertEqual(
            WhisperError.transcriptionFailed(code: -3).errorDescription,
            "Whisper transcription failed with error code -3"
        )
    }

    func testTranscribeEmptyFramesThrowsInvalidFramesFirst() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).bin")
        let whisper = Whisper(fromFileURL: url)

        do {
            _ = try await whisper.transcribe(audioFrames: [])
            XCTFail("Expected invalidFrames error")
        } catch let error as WhisperError {
            XCTAssertEqual(error, .invalidFrames)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTranscribeNonEmptyWithInvalidContextThrowsInitializationFailed() async {
        let url = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).bin")
        let whisper = Whisper(fromFileURL: url)

        do {
            _ = try await whisper.transcribe(audioFrames: [0.1, 0.2, 0.3])
            XCTFail("Expected initializationFailed error")
        } catch let error as WhisperError {
            XCTAssertEqual(error, .initializationFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSegmentInitialization() {
        let segment = Segment(startTime: 100, endTime: 220, text: "hello")
        XCTAssertEqual(segment.startTime, 100)
        XCTAssertEqual(segment.endTime, 220)
        XCTAssertEqual(segment.text, "hello")
    }
}
