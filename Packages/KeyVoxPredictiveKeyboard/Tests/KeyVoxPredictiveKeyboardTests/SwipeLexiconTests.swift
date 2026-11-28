import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Each bundled swipe lexicon is exactly the one its language's bundled dictionary, swipe
/// vocabulary, and swipe model build (`KeyVoxTypingHarness swipe-lexicon`), so a change to any of
/// them cannot leave it behind.
final class SwipeLexiconTests: XCTestCase {
    func testTheBundledLexiconIsTheOneTheDictionaryAndSwipeVocabularyBuild() throws {
        for language in [TypingLanguage.english, .german, .french, .spanish] {
            XCTAssertTrue(language.offersSwipeTyping, language.identifier)
            let built = try SwipeLexiconBuilder.fileData(
                words: try SwipeVocabulary.lexiconWords(of: PredictiveEngine(language: language)),
                settings: try SwipeModelSettings.bundled(for: language)
            )
            XCTAssertEqual(try Data(contentsOf: language.resources.dataURL(SwipeLexiconFormat.fileName)), built, language.identifier)
        }
    }
}
