import XCTest
@testable import KeyVoxCore

@MainActor
final class WhisperServiceLanguageTests: XCTestCase {
    func testUpdateLanguageStoresSupportedSelection() {
        let service = WhisperService()
        let spanish = DictationLanguage(rawValue: "es")

        service.updateLanguage(spanish)

        XCTAssertEqual(service.configuredLanguage, spanish)
    }

    func testUpdateLanguageFallsBackToAutomaticForUnsupportedSelection() {
        let service = WhisperService()

        service.updateLanguage(DictationLanguage(rawValue: "unknown"))

        XCTAssertEqual(service.configuredLanguage, .automatic)
    }
}
