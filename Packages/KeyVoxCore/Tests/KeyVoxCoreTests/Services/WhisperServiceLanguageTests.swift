import XCTest
import KeyVoxWhisper
@testable import KeyVoxCore

@MainActor
final class WhisperServiceLanguageTests: XCTestCase {
    func testUpdateLanguageStoresSupportedSelection() {
        let service = WhisperService()
        let spanish = DictationLanguage(rawValue: "es")

        service.updateLanguage(spanish)
        let params = WhisperParams.default
        service.applyConfiguredLanguage(to: params)

        XCTAssertEqual(service.configuredLanguage, spanish)
        XCTAssertEqual(params.language, .spanish)
    }

    func testUpdateLanguageAppliesAutomaticSelectionToRuntimeParameters() {
        let service = WhisperService()
        let params = WhisperParams.default

        service.updateLanguage(.automatic)
        service.applyConfiguredLanguage(to: params)

        XCTAssertEqual(params.language, .auto)
    }

    func testUpdateLanguageFallsBackToAutomaticForUnsupportedSelection() {
        let service = WhisperService()

        service.updateLanguage(DictationLanguage(rawValue: "unknown"))
        let params = WhisperParams.default
        service.applyConfiguredLanguage(to: params)

        XCTAssertEqual(service.configuredLanguage, .automatic)
        XCTAssertEqual(params.language, .auto)
    }
}
