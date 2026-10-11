/// The words the user picked from the suggestion bar in a row, so the next-word bar puts the
/// words that would repeat them after the others: a word already picked, unless it is a grammar
/// word every sentence repeats ("the", "and"), and any word that would write a three-word phrase
/// picked before. Always taking the bar's words otherwise walks the same words in a loop ("the
/// other side of the world and the other…"). Nothing leaves the bar; words are compared the way
/// personal words are.
struct RepeatedPicks {
    private let picked: Set<String>
    private let phrases: Set<[String]>
    private let grammarWords: GrammarWords

    /// - Parameter pickedWords: The words picked in a row, newest first.
    init(pickedWords: [String], grammarWords: GrammarWords) {
        let words = pickedWords.reversed().map(PersonalVocabulary.key)
        picked = Set(words)
        phrases = words.count < 3 ? [] : Set((0...(words.count - 3)).map { Array(words[$0..<($0 + 3)]) })
        self.grammarWords = grammarWords
    }

    /// Whether `word` right after `previousWords`, newest first, would repeat a pick.
    func repeats(_ word: String, after previousWords: [String]) -> Bool {
        let key = PersonalVocabulary.key(word)
        if picked.contains(key), grammarWords.contains(key) == false {
            return true
        }
        guard previousWords.count >= 2 else { return false }
        return phrases.contains([previousWords[1], previousWords[0], word].map(PersonalVocabulary.key))
    }

    /// `words`, best first, with the ones that would repeat a pick after the others.
    func ordering(_ words: [String], after previousWords: [String]) -> [String] {
        let repeating = words.filter { repeats($0, after: previousWords) }
        return words.filter { repeats($0, after: previousWords) == false } + repeating
    }
}
