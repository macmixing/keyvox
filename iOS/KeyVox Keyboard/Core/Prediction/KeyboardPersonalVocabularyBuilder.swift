import KeyVoxPredictiveKeyboard
import UIKit

/// Builds the user's personal vocabulary from their KeyVox Dictionary and the system
/// lexicon. The lexicon's names, such as contacts, are known names; its text replacements
/// expand.
enum KeyboardPersonalVocabularyBuilder {
    static func vocabulary(dictionaryPhrases: [String], lexicon: UILexicon?) -> PersonalVocabulary {
        var knownNames: [String] = []
        var replacements: [PersonalVocabulary.TextReplacement] = []
        for entry in lexicon?.entries ?? [] {
            if entry.userInput.caseInsensitiveCompare(entry.documentText) == .orderedSame {
                knownNames.append(entry.documentText)
            } else {
                replacements.append(PersonalVocabulary.TextReplacement(
                    shortcut: entry.userInput,
                    expansion: entry.documentText
                ))
            }
        }
        return PersonalVocabulary(
            words: dictionaryPhrases,
            knownNames: knownNames,
            textReplacements: replacements
        )
    }
}
