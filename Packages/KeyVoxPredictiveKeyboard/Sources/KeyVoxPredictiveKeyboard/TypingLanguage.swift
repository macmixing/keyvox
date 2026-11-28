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
    /// The letters single-letter edits of a typed word try, in the order they are tried.
    let editLetters: String
    /// The letters a short typed word needs one of to be taken as an attempt at a word.
    let vowels: String
    /// The marks that open a sentence before its first word.
    public let sentenceOpeningMarks: Set<Character>

    /// Whether a word typed right after `text` starts a sentence (`TypingTextContext.startsSentence`),
    /// the language's sentence opening marks after the sentence start leaving it where it is.
    public func startsSentence(after text: String) -> Bool {
        TypingTextContext.startsSentence(after: text, openingMarks: sentenceOpeningMarks)
    }

    /// The bundled language in the folder `identifier`, drawn in the layout named `letterLayout`,
    /// one of the layouts it offers (`letterLayouts`), or in its default layout when nil.
    /// - Throws: `PredictiveKeyboardError.invalidLetterLayout` for a layout the language does not
    ///   offer.
    public static func bundled(identifier: String, letterLayout layoutName: String? = nil) throws -> TypingLanguage {
        let ownResources = try TypingLanguageResources(identifier: identifier)
        let manifest: TypingLanguageManifest
        let layouts: TypingLanguageLetterLayouts
        do {
            let data = try Data(contentsOf: ownResources.url("language.json"))
            let decoder = JSONDecoder()
            manifest = try decoder.decode(TypingLanguageManifest.self, from: data)
            layouts = try decoder.decode(TypingLanguageLetterLayouts.self, from: data)
        } catch let error as PredictiveKeyboardError {
            throw error
        } catch {
            throw PredictiveKeyboardError.invalidTypingLanguage(identifier)
        }
        guard layouts.identifier == identifier else {
            throw PredictiveKeyboardError.invalidTypingLanguage(identifier)
        }
        let resources = try manifest.sharedDataFolder.map(ownResources.sharingData(withFolder:)) ?? ownResources
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
        sentenceOpeningMarks = Set(manifest.sentenceOpeningMarks ?? "")
    }
}
