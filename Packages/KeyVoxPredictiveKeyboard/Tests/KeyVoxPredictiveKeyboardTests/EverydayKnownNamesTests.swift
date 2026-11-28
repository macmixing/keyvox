import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A contact name that is an everyday word of one of the user's typing languages stays out of
/// another selected language's suggestions and corrections, as it does in its own language.
final class EverydayKnownNamesTests: XCTestCase {
    func testNameEverydayInAnotherSelectedLanguageStaysOutOfSuggestions() throws {
        let word = try likeliestEverydayWord(of: .english, unknownTo: .spanish)
        let name = word.prefix(1).uppercased() + word.dropFirst()
        let vocabulary = PersonalVocabulary(words: [], knownNames: [name], textReplacements: [])
        let request = PredictiveTypingSession(language: .spanish).request(textBeforeCursor: word)
        let withoutContacts = try PredictionComputer(engine: PredictiveEngine(language: .spanish)).compute(request)

        let judgedInSpanishOnly = try PredictionComputer(engine: PredictiveEngine(language: .spanish))
        try judgedInSpanishOnly.updateVocabulary(vocabulary)
        XCTAssertNotEqual(try judgedInSpanishOnly.compute(request).bar, withoutContacts.bar)

        let judgedInEverySelectedLanguage = try PredictionComputer(engine: PredictiveEngine(language: .spanish))
        try judgedInEverySelectedLanguage.updateVocabulary(
            vocabulary,
            everydayKnownNames: EverydayKnownNames(knownNames: vocabulary.knownNames, languages: [.spanish, .english])
        )
        let result = try judgedInEverySelectedLanguage.compute(request)
        XCTAssertEqual(result.bar, withoutContacts.bar)
        XCTAssertEqual(result.autocorrection, withoutContacts.autocorrection)
    }

    /// The likeliest lowercase word of `language`'s dictionary that is no word of `other`'s, nor one
    /// written there without its apostrophe, and that neither spells only with capitals.
    private func likeliestEverydayWord(of language: TypingLanguage, unknownTo other: TypingLanguage) throws -> String {
        let engine = try PredictiveEngine(language: language)
        let otherEngine = try PredictiveEngine(language: other)
        let isOtherWord = { (word: String) in try otherEngine.analyze(word: word).wordIsValid }
        for word in try engine.dictionaryWords().sorted(by: { $0.probability > $1.probability })
        where word.isOfferable && word.spelling.allSatisfy(\.isLowercase) {
            let spelling = word.spelling
            if engine.capitalizedSpellings.spelling(of: spelling) == nil,
               otherEngine.capitalizedSpellings.spelling(of: spelling) == nil,
               try isOtherWord(spelling) == false,
               try MissingApostrophe.isMissing(from: spelling, isWord: isOtherWord) == false {
                return spelling
            }
        }
        throw NoSuchWord()
    }

    private struct NoSuchWord: Error {}
}
