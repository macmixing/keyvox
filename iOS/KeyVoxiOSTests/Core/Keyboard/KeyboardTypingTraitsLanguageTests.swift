import Foundation
import KeyVoxPredictiveKeyboard
import Testing
import UIKit
@testable import KeyVox_iOS

/// Swiping follows the typing language: a field that allows it swipes in a language with a swipe
/// model and only taps in one without.
struct KeyboardTypingTraitsLanguageTests {
    @Test func swipingNeedsTheLanguagesSwipeModel() throws {
        let defaults = try #require(UserDefaults(suiteName: "KeyboardTypingTraitsLanguageTests"))
        defaults.removePersistentDomain(forName: "KeyboardTypingTraitsLanguageTests")
        let settings = KeyboardAppSettingsStore(defaults: defaults)
        let proxy = PlainFieldProxy()

        let english = KeyboardTypingTraits(proxy: proxy, settings: settings, language: try TypingLanguage.bundled(identifier: "en"))
        let spanish = KeyboardTypingTraits(proxy: proxy, settings: settings, language: try TypingLanguage.bundled(identifier: "es"))

        #expect(english.allowsSwipeTyping)
        #expect(spanish.allowsSwipeTyping == false)
        #expect(spanish.allowsPredictions)
        #expect(spanish.allowsAutocorrection)
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
