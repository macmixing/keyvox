import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A word of a KeyVox Dictionary phrase keeps the phrase's capitals on its own unless it is a
/// dictionary word, and one written without its apostrophe is typed as if no phrase had it.
final class DictionaryPhraseTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
        try computer.updateVocabulary(PersonalVocabulary(
            words: ["Dom Esposito", "Dont Answer"],
            textReplacements: []
        ))
    }

    func testRarePhraseWordKeepsItsCapitalsOnItsOwn() throws {
        XCTAssertEqual(try autocorrection(typing: "hi esposito"), "Esposito")
    }

    func testPhraseWordMissingItsApostropheIsCorrectedAsWithoutThePhrase() throws {
        let withoutDictionary = PredictionComputer(engine: try EnglishPredictiveEngine())
        let request = PredictiveTypingSession().request(textBeforeCursor: "I dont")
        XCTAssertNotNil(try withoutDictionary.compute(request).autocorrection)
        XCTAssertEqual(try autocorrection(typing: "I dont"), try withoutDictionary.compute(request).autocorrection)
    }

    private func autocorrection(typing text: String) throws -> String? {
        let request = PredictiveTypingSession().request(textBeforeCursor: text)
        return try computer.compute(request).autocorrection
    }
}
