import XCTest
@testable import KeyVoxPredictiveKeyboard

final class LetterKeyLayoutTests: XCTestCase {
    func testEveryLayoutALanguageNamesLoads() throws {
        let language = TypingLanguage.english
        XCTAssertFalse(language.alternativeLetterLayouts.contains(language.letterLayout.identifier))
        for identifier in language.alternativeLetterLayouts {
            XCTAssertEqual(try LetterKeyLayout.bundled(identifier: identifier).identifier, identifier)
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
