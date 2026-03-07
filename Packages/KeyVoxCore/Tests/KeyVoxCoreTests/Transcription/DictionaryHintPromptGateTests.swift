import XCTest
@testable import KeyVoxCore

final class DictionaryHintPromptGateTests: XCTestCase {
    func testSkipsVeryShortUtterances() {
        XCTAssertFalse(
            DictionaryHintPromptGate.shouldUseHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.28,
                maxActiveSignalRunDuration: 0.24
            )
        )

        XCTAssertFalse(
            DictionaryHintPromptGate.shouldUseHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.62,
                maxActiveSignalRunDuration: 0.20
            )
        )
    }

    func testAllowsQualifiedSignalRuns() {
        XCTAssertTrue(
            DictionaryHintPromptGate.shouldUseHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.65,
                maxActiveSignalRunDuration: 0.44
            )
        )
    }

    func testAllowsExactActiveSignalRunThreshold() {
        XCTAssertTrue(
            DictionaryHintPromptGate.shouldUseHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.65,
                maxActiveSignalRunDuration: 0.35
            )
        )
    }

    func testAllowsExactCaptureDurationThreshold() {
        XCTAssertTrue(
            DictionaryHintPromptGate.shouldUseHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: false,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.45,
                maxActiveSignalRunDuration: 0.44
            )
        )
    }

    func testRejectsLikelySilence() {
        XCTAssertFalse(
            DictionaryHintPromptGate.shouldUseHintPrompt(
                lastCaptureHadActiveSignal: true,
                lastCaptureWasLikelySilence: true,
                lastCaptureWasLongTrueSilence: false,
                lastCaptureDuration: 0.70,
                maxActiveSignalRunDuration: 0.44
            )
        )
    }
}
