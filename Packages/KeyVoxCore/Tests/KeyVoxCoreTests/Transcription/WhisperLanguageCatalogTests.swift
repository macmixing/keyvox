import XCTest
@testable import KeyVoxCore

final class WhisperLanguageCatalogTests: XCTestCase {
    func testCatalogIncludesAutomaticAndWhisperBaseLanguages() {
        XCTAssertTrue(WhisperBaseLanguageCatalog.supports(.automatic))
        XCTAssertTrue(WhisperBaseLanguageCatalog.supports(DictationLanguage(rawValue: "en")))
        XCTAssertTrue(WhisperBaseLanguageCatalog.supports(DictationLanguage(rawValue: "es")))
        XCTAssertTrue(WhisperBaseLanguageCatalog.supports(DictationLanguage(rawValue: "hy")))
    }

    func testCatalogRejectsLanguagesUnavailableToWhisperBase() {
        XCTAssertFalse(WhisperBaseLanguageCatalog.supports(DictationLanguage(rawValue: "yue")))
        XCTAssertFalse(WhisperBaseLanguageCatalog.supports(DictationLanguage(rawValue: "unknown")))
    }
}
