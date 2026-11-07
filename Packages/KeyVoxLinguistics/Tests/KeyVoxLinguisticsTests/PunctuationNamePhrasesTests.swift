import XCTest
@testable import KeyVoxLinguistics

final class PunctuationNamePhrasesTests: XCTestCase {
    func testFindsListedPhraseAroundMarkName() throws {
        let phrases = try PunctuationNamePhrases()

        XCTAssertEqual(listedPhrase(around: "period", in: "We started the trial period today", phrases), "trial period")
        XCTAssertEqual(listedPhrase(around: "period", in: "It ends this billing period.", phrases), "billing period")
        XCTAssertEqual(listedPhrase(around: "colon", in: "I read about colon cancer.", phrases), "colon cancer")
        XCTAssertEqual(listedPhrase(around: "comma", in: "I use the Oxford comma", phrases), "Oxford comma")
        XCTAssertEqual(listedPhrase(around: "full stop", in: "It is a Japanese full stop", phrases), "Japanese full stop")
    }

    func testMatchesMisheardMarkNameByItsWrittenName() throws {
        let phrases = try PunctuationNamePhrases()
        let text = "It reached the sigmoid Colin"
        let nameRange = try XCTUnwrap(text.range(of: "Colin"))

        let range = try XCTUnwrap(phrases.phraseRange(around: nameRange, named: "colon", in: text))

        XCTAssertEqual(String(text[range]), "sigmoid Colin")
    }

    func testIgnoresUnlistedOrInterruptedPhrases() throws {
        let phrases = try PunctuationNamePhrases()

        XCTAssertNil(listedPhrase(around: "period", in: "I went to the store period", phrases))
        XCTAssertNil(listedPhrase(around: "period", in: "We started the trial, period", phrases))
        XCTAssertNil(listedPhrase(around: "period", in: "period", phrases))
    }

    private func listedPhrase(around name: String, in text: String, _ phrases: PunctuationNamePhrases) -> String? {
        guard let nameRange = text.range(of: name),
              let range = phrases.phraseRange(around: nameRange, named: name, in: text) else {
            return nil
        }
        return String(text[range])
    }
}
