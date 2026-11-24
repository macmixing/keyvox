import Foundation

/// One language the keyboard types in: its bundled files, its letter layout, and the rules
/// that differ from one language to another, read from its folder in `PredictiveData`.
public struct TypingLanguage: Sendable {
    /// The language's folder name, such as `en`.
    public let identifier: String
    public let resources: TypingLanguageResources
    public let letterLayout: LetterKeyLayout
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
        return TypingLanguage(manifest: manifest, resources: resources)
    }

    private init(manifest: TypingLanguageManifest, resources: TypingLanguageResources) {
        identifier = manifest.identifier
        self.resources = resources
        letterLayout = LetterKeyLayout(rows: manifest.letterRows)
        casing = WordCasing(alwaysCapitalizedWords: manifest.alwaysCapitalizedWords)
        quotes = SmartQuotes(marks: manifest.quotationMarks)
        editLetters = manifest.editLetters
        vowels = manifest.vowels
    }
}
