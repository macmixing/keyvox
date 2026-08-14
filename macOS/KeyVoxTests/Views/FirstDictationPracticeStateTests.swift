import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class FirstDictationPracticeStateTests: XCTestCase {
    func testCompletesWhenFieldUpdatesAfterSuccessfulDictation() {
        let state = FirstDictationPracticeState()
        let baselineRevision = 4
        let dictatedText = UUID().uuidString

        state.startPractice(baselineDictationRevision: baselineRevision)
        state.captureExpectedDictationIfNeeded(
            revision: baselineRevision + 1,
            latestTranscription: dictatedText
        )

        XCTAssertFalse(state.hasReceivedFirstDictation)

        state.text = dictatedText

        XCTAssertTrue(state.hasReceivedFirstDictation)
    }
}
