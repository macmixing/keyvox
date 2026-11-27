import Foundation
import KeyVoxPredictiveKeyboard
import KeyVoxTypingLanguageCatalog

/// The language the keyboard types in: its letter layout, quotation marks, casing, and the
/// files its suggestions and corrections come from. It is one of the languages the user selected in
/// the KeyVox app, in the layout chosen for it: the one the keyboard last typed in, or the first
/// selected when that one is no longer selected. Only this language's files are read; its
/// dictionary and models load where predictions need them. Use from the main thread.
enum KeyboardTypingLanguage {
    /// The languages the keyboard bundles, with the layouts each offers.
    static let catalog: TypingLanguageCatalog = {
        do {
            return try TypingLanguageCatalog.bundled()
        } catch {
            preconditionFailure("the bundled typing languages did not load: \(error)")
        }
    }()

    private static var state = resolved(settings: KeyboardAppSettingsStore())

    /// The language the keyboard types in.
    static var current: TypingLanguage {
        state.language
    }

    /// The languages the user selected, in the order the space bar switches through them.
    static var selection: KeyboardTypingLanguageSelection {
        state.selection
    }

    /// Rereads the user's languages and layouts and the language last used, as each time the
    /// keyboard shows, and types in the language they give. Returns whether the language or its
    /// layout changed.
    @discardableResult
    static func adoptSettings(_ settings: KeyboardAppSettingsStore) -> Bool {
        let previous = state.language
        state = resolved(settings: settings, reusing: previous)
        return isSame(state.language, previous) == false
    }

    /// Types in the selected language `offset` places from the current one, wrapping around, and
    /// saves it as the language last used. Returns whether the language changed, which it never does
    /// with one language selected.
    @discardableResult
    static func switchLanguage(by offset: Int, settings: KeyboardAppSettingsStore) -> Bool {
        let previous = state.language
        guard let next = state.selection.language(offset, from: previous.identifier),
              next.identifier != previous.identifier else {
            return false
        }
        settings.lastTypingLanguage = next.identifier
        state = resolved(settings: settings, reusing: previous)
        return isSame(state.language, previous) == false
    }

    private static func resolved(
        settings: KeyboardAppSettingsStore,
        reusing loaded: TypingLanguage? = nil
    ) -> (selection: KeyboardTypingLanguageSelection, language: TypingLanguage) {
        let selection = settings.typingLanguageSelection(catalog: catalog)
        guard let active = selection.activeLanguage(lastUsed: settings.lastTypingLanguage) else {
            preconditionFailure("the keyboard bundles no typing language")
        }
        if let loaded, loaded.identifier == active.identifier, loaded.letterLayout.identifier == active.letterLayout {
            return (selection, loaded)
        }
        do {
            return (selection, try TypingLanguage.bundled(identifier: active.identifier, letterLayout: active.letterLayout))
        } catch {
            preconditionFailure("the bundled typing language \(active.identifier) did not load: \(error)")
        }
    }

    private static func isSame(_ language: TypingLanguage, _ other: TypingLanguage) -> Bool {
        language.identifier == other.identifier
            && language.letterLayout.identifier == other.letterLayout.identifier
    }
}
