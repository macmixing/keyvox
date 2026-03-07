import XCTest
@testable import KeyVoxCore

@MainActor
final class WhisperServiceRequestStateTests: XCTestCase {
    func testStaleRequestCannotOverwriteCurrentTranscriptionState() {
        let service = WhisperService()
        let staleRequestID = service.beginTranscriptionRequest()
        let currentRequestID = service.beginTranscriptionRequest()

        var staleCompletionCalled = false
        service.finishSuccessfulRequest(
            staleRequestID,
            usedDictionaryHintPrompt: false,
            finalText: "stale",
            likelyNoSpeech: false,
            detectedLanguageCode: "en"
        ) { _ in
            staleCompletionCalled = true
        }

        XCTAssertFalse(staleCompletionCalled)
        XCTAssertEqual(service.transcriptionText, "")
        XCTAssertFalse(service.lastResultWasLikelyNoSpeech)

        var currentCompletionText: String?
        service.finishSuccessfulRequest(
            currentRequestID,
            usedDictionaryHintPrompt: false,
            finalText: "current",
            likelyNoSpeech: false,
            detectedLanguageCode: "en"
        ) { result in
            currentCompletionText = result?.text
        }

        XCTAssertEqual(currentCompletionText, "current")
        XCTAssertEqual(service.transcriptionText, "current")
        XCTAssertFalse(service.lastResultWasLikelyNoSpeech)
    }
}
