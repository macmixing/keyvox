import Foundation
import KeyVoxPredictiveKeyboard
import Testing
import UIKit
@testable import KeyVox_iOS

/// Swiping follows the typing language: a field that allows it swipes in a language with a swipe
/// model and only taps in one without. Every bundled language bundles one.
struct KeyboardTypingTraitsLanguageTests {
    @Test(arguments: ["en", "de", "es", "fr"])
    func swipingNeedsTheLanguagesSwipeModel(identifier: String) throws {
        let defaults = try #require(UserDefaults(suiteName: "KeyboardTypingTraitsLanguageTests"))
        defaults.removePersistentDomain(forName: "KeyboardTypingTraitsLanguageTests")
        let settings = KeyboardAppSettingsStore(defaults: defaults)
        let language = try TypingLanguage.bundled(identifier: identifier)

        let traits = KeyboardTypingTraits(proxy: PlainFieldProxy(), settings: settings, language: language)

        #expect(language.offersSwipeTyping)
        #expect(traits.allowsSwipeTyping == language.offersSwipeTyping)
        #expect(traits.allowsPredictions)
        #expect(traits.allowsAutocorrection)
    }
}

/// A plain text field with every trait at its default.
private final class PlainFieldProxy: NSObject, UITextDocumentProxy {
    var documentContextBeforeInput: String? { nil }
    var documentContextAfterInput: String? { nil }
    var selectedText: String? { nil }
    var documentInputMode: UITextInputMode? { nil }
    var documentIdentifier: UUID { UUID() }
    var hasText: Bool { false }

    func adjustTextPosition(byCharacterOffset offset: Int) {}
    func setMarkedText(_ markedText: String, selectedRange: NSRange) {}
    func unmarkText() {}
    func insertText(_ text: String) {}
    func deleteBackward() {}
}
