import XCTest
@testable import KeyVoxWhisper

final class WhisperParamsTests: XCTestCase {
    func testInitialPromptTrimsAndClears() {
        let params = WhisperParams.default

        params.initialPrompt = "   KeyVox Domain   "
        XCTAssertEqual(params.initialPrompt, "KeyVox Domain")

        params.initialPrompt = "   "
        XCTAssertEqual(params.initialPrompt, "")
    }

    func testLanguageRoundtrip() {
        let params = WhisperParams.default
        params.language = .english
        XCTAssertEqual(params.language, .english)

        params.language = .auto
        XCTAssertEqual(params.language, .auto)
    }

    func testSuppressNonSpeechAlias() {
        let params = WhisperParams.default
        params.suppress_non_speech_tokens = true
        XCTAssertTrue(params.suppress_non_speech_tokens)

        params.suppress_non_speech_tokens = false
        XCTAssertFalse(params.suppress_non_speech_tokens)
    }
}
