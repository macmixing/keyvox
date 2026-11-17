import Foundation
import XCTest
@testable import KeyVoxCore

final class DictationLanguageDisplayNameFormatterTests: XCTestCase {
    func testLanguageNamesStartWithCapitalLetterInEveryAppLanguage() {
        let languages = WhisperBaseLanguageCatalog.supportedLanguages.filter { !$0.isAutomatic }
        XCTAssertFalse(languages.isEmpty)

        for identifier in ["en_US", "de_DE", "es_ES", "fr_FR"] {
            let locale = Locale(identifier: identifier)
            for language in languages {
                let name = DictationLanguageDisplayNameFormatter.displayName(for: language, locale: locale)
                guard let first = name.first, first.isLetter else { continue }
                XCTAssertEqual(
                    String(first),
                    String(first).uppercased(with: locale),
                    "\(language.rawValue) in \(identifier) starts lowercase: \(name)"
                )
            }
        }
    }

    func testCapitalizationKeepsTheRestOfTheLocaleName() {
        let locale = Locale(identifier: "es_ES")
        let language = DictationLanguage(rawValue: "de")
        let localeName = try? XCTUnwrap(locale.localizedString(forLanguageCode: language.rawValue))
        let name = DictationLanguageDisplayNameFormatter.displayName(for: language, locale: locale)

        XCTAssertEqual(name.dropFirst(), localeName?.dropFirst())
        XCTAssertEqual(name.lowercased(with: locale), localeName?.lowercased(with: locale))
    }
}
