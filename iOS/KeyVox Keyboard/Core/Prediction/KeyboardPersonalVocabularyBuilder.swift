import KeyVoxPredictiveKeyboard
import UIKit

/// Builds the user's personal vocabulary from their KeyVox Dictionary and the system
/// lexicon, which holds contact names and the user's text replacements.
enum KeyboardPersonalVocabularyBuilder {
    static func vocabulary(dictionaryPhrases: [String], lexicon: UILexicon?) -> PersonalVocabulary {
        var words = dictionaryPhrases
        var replacements: [PersonalVocabulary.TextReplacement] = []
        for entry in lexicon?.entries ?? [] {
            if entry.userInput.caseInsensitiveCompare(entry.documentText) == .orderedSame {
                words.append(entry.documentText)
            } else {
                replacements.append(PersonalVocabulary.TextReplacement(
                    shortcut: entry.userInput,
                    expansion: entry.documentText
                ))
            }
        }
        return PersonalVocabulary(words: words, textReplacements: replacements)
    }
}
