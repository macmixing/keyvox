import Foundation
import KeyVoxTypingLanguageCatalog

/// One language the keyboard types in: its bundled files, its letter layout, and the rules
/// that differ from one language to another, read from its folder in `PredictiveData`.
public struct TypingLanguage: Sendable {
    /// The language's folder name, such as `en`.
    public let identifier: String
    public let resources: TypingLanguageResources
    /// The letter layout the keyboard shows: the language's default unless it was loaded in
    /// another of `letterLayouts`.
    public let letterLayout: LetterKeyLayout
    /// The names of the other letter layouts Apple's keyboard offers for the language, in Apple's
    /// order, each loadable with `LetterKeyLayout.bundled(identifier:)`.
    public let alternativeLetterLayouts: [String]
    /// The names of every letter layout the language offers, in Apple's order: the default first.
    public let letterLayouts: [String]
    public let casing: WordCasing
    public let quotes: SmartQuotes
    /// How the language's text is read: the apostrophe it types inside words, and whether a
    /// period after a digit ends a sentence.
    public let textRules: TypingTextRules
    /// The letters single-letter edits of a typed word try, in the order they are tried.
    let editLetters: String
    /// The letters a short typed word needs one of to be taken as an attempt at a word.
    let vowels: String

    /// Whether a word typed right after `text` starts a sentence (`TypingTextContext.startsSentence`),
    /// read by the language's text rules.
    public func startsSentence(after text: String) -> Bool {
        TypingTextContext.startsSentence(after: text, rules: textRules)
    }

    /// The bundled language in the folder `identifier`, drawn in the layout named `letterLayout`,
    /// one of the layouts it offers (`letterLayouts`), or in its default layout when nil.
    /// - Throws: `PredictiveKeyboardError.invalidLetterLayout` for a layout the language does not
    ///   offer.
    public static func bundled(identifier: String, letterLayout layoutName: String? = nil) throws -> TypingLanguage {
        let resources = try TypingLanguageResources(identifier: identifier)
        let manifest: TypingLanguageManifest
        let layouts: TypingLanguageLetterLayouts
        do {
            let data = try Data(contentsOf: resources.url("language.json"))
            let decoder = JSONDecoder()
            manifest = try decoder.decode(TypingLanguageManifest.self, from: data)
            layouts = try decoder.decode(TypingLanguageLetterLayouts.self, from: data)
        } catch let error as PredictiveKeyboardError {
            throw error
        } catch {
            throw PredictiveKeyboardError.invalidTypingLanguage(identifier)
        }
        // The closing single mark is what the apostrophe key types inside words, one character.
        guard layouts.identifier == identifier, manifest.quotationMarks.closingSingle.count == 1 else {
            throw PredictiveKeyboardError.invalidTypingLanguage(identifier)
        }
        let chosenLayout = layoutName ?? layouts.defaultLetterLayout
        guard layouts.letterLayouts.contains(chosenLayout) else {
            throw PredictiveKeyboardError.invalidLetterLayout(chosenLayout)
        }
        let letterLayout = try LetterKeyLayout.bundled(identifier: chosenLayout)
        return TypingLanguage(manifest: manifest, layouts: layouts, resources: resources, letterLayout: letterLayout)
    }

    private init(
        manifest: TypingLanguageManifest,
        layouts: TypingLanguageLetterLayouts,
        resources: TypingLanguageResources,
        letterLayout: LetterKeyLayout
    ) {
        identifier = layouts.identifier
        self.resources = resources
        self.letterLayout = letterLayout
        alternativeLetterLayouts = layouts.alternativeLetterLayouts
        letterLayouts = layouts.letterLayouts
        casing = WordCasing(alwaysCapitalizedWords: manifest.alwaysCapitalizedWords)
        quotes = SmartQuotes(marks: manifest.quotationMarks)
        editLetters = manifest.editLetters
        vowels = manifest.vowels
        textRules = TypingTextRules(
            apostrophe: Character(manifest.quotationMarks.closingSingle),
            ordinalPeriods: manifest.ordinalPeriods ?? false
        )
    }
}
