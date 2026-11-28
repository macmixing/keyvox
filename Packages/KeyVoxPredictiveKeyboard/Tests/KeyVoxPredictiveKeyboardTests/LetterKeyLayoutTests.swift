import XCTest
@testable import KeyVoxPredictiveKeyboard

final class LetterKeyLayoutTests: XCTestCase {
    func testEveryLayoutALanguageNamesLoads() throws {
        for language in [TypingLanguage.english, .spanish] {
            XCTAssertFalse(language.alternativeLetterLayouts.contains(language.letterLayout.identifier))
            for identifier in language.alternativeLetterLayouts {
                XCTAssertEqual(try LetterKeyLayout.bundled(identifier: identifier).identifier, identifier)
            }
        }
    }

    func testALanguageLoadsInEveryLayoutItOffersAndNoOther() throws {
        let english = TypingLanguage.english
        XCTAssertEqual(english.letterLayouts, [english.letterLayout.identifier] + english.alternativeLetterLayouts)
        for identifier in english.letterLayouts {
            let language = try TypingLanguage.bundled(identifier: english.identifier, letterLayout: identifier)
            XCTAssertEqual(language.letterLayout.identifier, identifier)
            XCTAssertEqual(language.letterLayouts, english.letterLayouts)
        }
        let notOffered = try XCTUnwrap(
            FileManager.default.contentsOfDirectory(
                at: XCTUnwrap(KeyVoxPredictiveKeyboardResources.bundle.url(forResource: "PredictiveData", withExtension: nil))
                    .appendingPathComponent("letter_layouts", isDirectory: true),
                includingPropertiesForKeys: nil
            )
            .map { $0.deletingPathExtension().lastPathComponent }
            .first { english.letterLayouts.contains($0) == false }
        )
        XCTAssertThrowsError(try TypingLanguage.bundled(identifier: english.identifier, letterLayout: notOffered))
    }

    func testSwipesDecodeOnTheKeysOfTheLayoutTheLanguageLoadedIn() throws {
        let english = TypingLanguage.english
        for identifier in english.alternativeLetterLayouts {
            let language = try TypingLanguage.bundled(identifier: english.identifier, letterLayout: identifier)
            let computer = PredictionComputer(engine: try PredictiveEngine(language: language))
            let words = try computer.swipeWords(
                for: SwipePath.through("people", on: language.letterLayout),
                previousWords: [],
                wordCase: .asSpelled,
                limit: 1
            )
            XCTAssertEqual(words, ["people"], identifier)
        }
    }

    func testEveryBundledLayoutAimsAtItsLettersInsideItsRows() throws {
        let folder = try XCTUnwrap(
            KeyVoxPredictiveKeyboardResources.bundle.url(forResource: "PredictiveData", withExtension: nil)
        ).appendingPathComponent("letter_layouts", isDirectory: true)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        XCTAssertFalse(files.isEmpty)
        for file in files {
            let layout = try LetterKeyLayout.bundled(identifier: file.deletingPathExtension().lastPathComponent)
            let letters = layout.rows.flatMap(\.items).compactMap { item -> Character? in
                guard case let .character(text) = item, let character = text.first, character.isLetter else {
                    return nil
                }
                return character
            }
            XCTAssertEqual(layout.defaultGeometry.map(\.character), letters, layout.identifier)
            for key in layout.defaultGeometry {
                XCTAssertGreaterThanOrEqual(key.frame.minX, 0, layout.identifier)
                XCTAssertLessThanOrEqual(key.frame.maxX, layout.width * 100 + 0.001, layout.identifier)
            }
        }
    }
}
