import XCTest
import whisper
@testable import KeyVoxWhisper

final class WhisperParamsTests: XCTestCase {
    func testStrategyInitializerSetsExpectedWhisperStrategy() {
        let greedy = WhisperParams(strategy: .greedy)
        XCTAssertEqual(greedy.whisperParams.strategy, WHISPER_SAMPLING_GREEDY)

        let beam = WhisperParams(strategy: .beamSearch)
        XCTAssertEqual(beam.whisperParams.strategy, WHISPER_SAMPLING_BEAM_SEARCH)
    }

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

    func testDynamicMemberReadWriteRoundtrip() {
        let params = WhisperParams.default
        params.n_threads = 6

        XCTAssertEqual(params.n_threads, 6)
    }

    func testLanguageGetterFallsBackToAutoWhenRawValueUnknown() {
        let params = WhisperParams.default
        let unknown = strdup("zz")
        XCTAssertNotNil(unknown)

        params.whisperParams.language = UnsafePointer(unknown)
        XCTAssertEqual(params.language, .auto)

        free(unknown)
    }
}
