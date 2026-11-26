import Foundation

/// One language the keyboard types in: its bundled files, its letter layout, and the rules
/// that differ from one language to another, read from its folder in `PredictiveData`.
public struct TypingLanguage: Sendable {
    /// The language's folder name, such as `en`.
    public let identifier: String
    public let resources: TypingLanguageResources
    /// The letter layout the keyboard shows.
    public let letterLayout: LetterKeyLayout
    /// The names of the other letter layouts Apple's keyboard offers for the language, in Apple's
    /// order, each loadable with `LetterKeyLayout.bundled(identifier:)`.
    public let alternativeLetterLayouts: [String]
    public let casing: WordCasing
    public let quotes: SmartQuotes
    /// The letters single-letter edits of a typed word try, in the order they are tried.
    let editLetters: String
    /// The letters a short typed word needs one of to be taken as an attempt at a word.
    let vowels: String

    /// The bundled language in the folder `identifier`.
    public static func bundled(identifier: String) throws -> TypingLanguage {
        let resources = try TypingLanguageResources(identifier: identifier)
        let manifest: TypingLanguageManifest
        do {
            manifest = try JSONDecoder().decode(
                TypingLanguageManifest.self,
                from: Data(contentsOf: resources.url("language.json"))
            )
        } catch let error as PredictiveKeyboardError {
            throw error
        } catch {
            throw PredictiveKeyboardError.invalidTypingLanguage(identifier)
        }
        guard manifest.identifier == identifier else {
            throw PredictiveKeyboardError.invalidTypingLanguage(identifier)
        }
        let letterLayout = try LetterKeyLayout.bundled(identifier: manifest.defaultLetterLayout)
        return TypingLanguage(manifest: manifest, resources: resources, letterLayout: letterLayout)
    }

    private init(manifest: TypingLanguageManifest, resources: TypingLanguageResources, letterLayout: LetterKeyLayout) {
        identifier = manifest.identifier
        self.resources = resources
        self.letterLayout = letterLayout
        alternativeLetterLayouts = manifest.alternativeLetterLayouts
        casing = WordCasing(alwaysCapitalizedWords: manifest.alwaysCapitalizedWords)
        quotes = SmartQuotes(marks: manifest.quotationMarks)
        editLetters = manifest.editLetters
        vowels = manifest.vowels
    }
}
