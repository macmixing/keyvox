import KeyVoxTypingLanguageCatalog
import XCTest
@testable import KeyVoxPredictiveKeyboard

final class TypingLanguageCatalogTests: XCTestCase {
    func testBundledCatalogListsEveryLanguageFolderWithTheLayoutsItsLanguageLoads() throws {
        let catalog = try TypingLanguageCatalog.bundled()
        let folder = try XCTUnwrap(
            KeyVoxPredictiveKeyboardResources.bundle.url(forResource: "PredictiveData", withExtension: nil)
        )
        let languageFolders = try FileManager.default.contentsOfDirectory(atPath: folder.path)
            .filter { FileManager.default.fileExists(atPath: folder.appendingPathComponent($0).appendingPathComponent("language.json").path) }
            .sorted()
        XCTAssertFalse(languageFolders.isEmpty)
        XCTAssertEqual(catalog.languages.map(\.identifier), languageFolders)
        for entry in catalog.languages {
            let language = try TypingLanguage.bundled(identifier: entry.identifier)
            XCTAssertEqual(entry.letterLayouts, language.letterLayouts)
            XCTAssertEqual(entry.letterLayouts.first, language.letterLayout.identifier)
        }
    }

    func testCatalogReadsTheCopyInsideAnotherBundle() throws {
        let host = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: host) }
        let data = host
            .appendingPathComponent(TypingLanguageCatalog.resourceBundleName, isDirectory: true)
            .appendingPathComponent("PredictiveData", isDirectory: true)
        let language = data.appendingPathComponent("xx", isDirectory: true)
        try FileManager.default.createDirectory(at: language, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: data.appendingPathComponent("letter_layouts", isDirectory: true),
            withIntermediateDirectories: true
        )
        try Data(#"{"identifier": "xx", "defaultLetterLayout": "B", "alternativeLetterLayouts": ["A", "C"]}"#.utf8)
            .write(to: language.appendingPathComponent("language.json"))

        let catalog = try XCTUnwrap(TypingLanguageCatalog(containingBundleURL: host))

        XCTAssertEqual(catalog.languages.map(\.identifier), ["xx"])
        XCTAssertEqual(catalog.language("xx")?.letterLayouts, ["B", "A", "C"])
        XCTAssertNil(TypingLanguageCatalog(containingBundleURL: language))
    }
}
