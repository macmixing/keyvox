import KeyVoxTypingLanguageCatalog
import Testing
@testable import KeyVox_iOS

/// The keyboard types in the saved languages it bundles, in their saved order, each with its saved
/// layout when the language offers it, and in one bundled language when nothing saved is bundled.
struct KeyboardTypingLanguageSelectionTests {
    private let catalog = TypingLanguageCatalog(languages: [
        TypingLanguageLetterLayouts(identifier: "fr-CA", defaultLetterLayout: "QWERTY", alternativeLetterLayouts: ["AZERTY"]),
        TypingLanguageLetterLayouts(identifier: "en", defaultLetterLayout: "QWERTY", alternativeLetterLayouts: ["AZERTY", "Dvorak"]),
        TypingLanguageLetterLayouts(identifier: "fr", defaultLetterLayout: "AZERTY-French", alternativeLetterLayouts: ["QWERTY"]),
    ])

    @Test func keepsSavedOrderAndDropsLanguagesNotBundledOrRepeated() {
        let selection = KeyboardTypingLanguageSelection(
            savedLanguages: ["fr", "xx", "en", "fr"],
            savedLetterLayouts: [:],
            catalog: catalog,
            fallbackLanguage: "en"
        )

        #expect(selection.identifiers == ["fr", "en"])
    }

    @Test func usesSavedLayoutOnlyWhenTheLanguageOffersIt() {
        let selection = KeyboardTypingLanguageSelection(
            savedLanguages: ["en", "fr"],
            savedLetterLayouts: ["en": "Dvorak", "fr": "Dvorak"],
            catalog: catalog,
            fallbackLanguage: "en"
        )

        #expect(selection.languages.map(\.letterLayout) == ["Dvorak", "AZERTY-French"])
        #expect(selection.languages.first?.letterLayouts == ["QWERTY", "AZERTY", "Dvorak"])
    }

    @Test func fallsBackToTheFallbackLanguageThenItsLanguageThenTheFirstBundled() {
        func fallback(_ language: String?) -> [String] {
            KeyboardTypingLanguageSelection(
                savedLanguages: ["xx"],
                savedLetterLayouts: [:],
                catalog: catalog,
                fallbackLanguage: language
            ).identifiers
        }

        #expect(fallback("fr-CA") == ["fr-CA"])
        #expect(fallback("fr-BE") == ["fr"])
        #expect(fallback("ja") == ["en"])
        #expect(fallback(nil) == ["en"])
    }

    @Test func selectsNothingWhenNothingIsBundled() {
        let selection = KeyboardTypingLanguageSelection(
            savedLanguages: ["en"],
            savedLetterLayouts: [:],
            catalog: TypingLanguageCatalog(languages: []),
            fallbackLanguage: "en"
        )

        #expect(selection.languages.isEmpty)
    }
}
