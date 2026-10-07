/// How the user's own words are written where they appear.
///
/// An entry that is a single word is always written the user's way. A word of an entry
/// phrase is written the phrase's way right after the phrase word before it, so "big
/// dictation" becomes "Big Dictation"; on its own it keeps the phrase's capitals only when
/// it is not an everyday word ("Esposito" from "Dom Esposito"), so "dictation" alone stays
/// as the bundled dictionary writes it. Every other word is left as it is.
struct PersonalWordForms: Sendable {
    static let empty = PersonalWordForms(vocabulary: .empty, everydayWords: [])

    private let vocabulary: PersonalVocabulary
    /// Phrase words the bundled dictionary knows, in `PersonalVocabulary.key` form.
    private let everydayWords: Set<String>

    /// - Parameter everydayWords: Phrase words the bundled dictionary knows, in any case.
    init(vocabulary: PersonalVocabulary, everydayWords: Set<String>) {
        self.vocabulary = vocabulary
        self.everydayWords = Set(everydayWords.map(PersonalVocabulary.key))
    }

    /// How `word` is written right after `previousWord`.
    func written(_ word: String, after previousWord: String?) -> String {
        if let entry = vocabulary.singleWordEntryForm(of: word) {
            return entry
        }
        if let previousWord, let inPhrase = vocabulary.phraseForm(of: word, after: previousWord) {
            return inPhrase
        }
        if let phraseWord = vocabulary.entryForm(of: word),
           everydayWords.contains(PersonalVocabulary.key(word)) == false {
            return phraseWord
        }
        return word
    }
}
