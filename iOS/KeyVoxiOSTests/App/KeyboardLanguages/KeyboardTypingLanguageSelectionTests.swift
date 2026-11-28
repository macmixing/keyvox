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

    @Test func typesInTheLastLanguageUsedWhileItIsSelectedElseTheFirstSelected() {
        let selection = KeyboardTypingLanguageSelection(
            savedLanguages: ["fr", "en"],
            savedLetterLayouts: [:],
            catalog: catalog,
            fallbackLanguage: "en"
        )

        #expect(selection.activeLanguage(lastUsed: "en")?.identifier == "en")
        #expect(selection.activeLanguage(lastUsed: "fr-CA")?.identifier == "fr")
        #expect(selection.activeLanguage(lastUsed: nil)?.identifier == "fr")
    }

    @Test func stepsThroughTheSelectedLanguagesInOrderWrappingAtEitherEnd() {
        let selection = KeyboardTypingLanguageSelection(
            savedLanguages: ["fr", "en", "fr-CA"],
            savedLetterLayouts: [:],
            catalog: catalog,
            fallbackLanguage: "en"
        )

        #expect(selection.language(1, from: "fr")?.identifier == "en")
        #expect(selection.language(1, from: "fr-CA")?.identifier == "fr")
        #expect(selection.language(-1, from: "fr")?.identifier == "fr-CA")
        #expect(selection.language(1, from: "xx") == nil)
    }

    @Test func stepsToItselfWithOneLanguage() {
        let selection = KeyboardTypingLanguageSelection(
            savedLanguages: ["en"],
            savedLetterLayouts: [:],
            catalog: catalog,
            fallbackLanguage: "en"
        )

        #expect(selection.language(1, from: "en")?.identifier == "en")
        #expect(selection.language(-1, from: "en")?.identifier == "en")
    }

    @Test func shortCodeAddsTheRegionOnlyWhenAnotherSelectedLanguageSharesTheCode() {
        #expect(KeyboardTypingLanguageName.shortCode(for: "en", among: ["en", "fr"]) == "EN")
        #expect(KeyboardTypingLanguageName.shortCode(for: "fr-CA", among: ["en", "fr-CA"]) == "FR")
        #expect(KeyboardTypingLanguageName.shortCode(for: "fr-CA", among: ["fr", "fr-CA"]) == "FR CA")
        #expect(KeyboardTypingLanguageName.shortCode(for: "fr", among: ["fr", "fr-CA"]) == "FR")
    }

    @Test func shortCodeLeavesOutARegionOfSeveralCountries() {
        #expect(KeyboardTypingLanguageName.shortCode(for: "es-419", among: ["es", "es-419"]) == "ES")
        #expect(KeyboardTypingLanguageName.shortCode(for: "es", among: ["es", "es-419"]) == "ES")
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
