import Foundation

/// Swipe typing: the words a swipe across the letter keys may have been, from the bundled
/// lexicon and the user's own words, written the way typing writes them.
extension PredictionComputer {
    /// The words `path` may have been swiped as, best first and at most `limit`, ready to
    /// insert: a text replacement shortcut expands, the user's words are written their way,
    /// a learned word or a dictionary word the user gives capitals takes them, a name keeps its
    /// capitals, and `wordCase` carries the shift state as it would for typed letters.
    /// - Parameters:
    ///   - path: The finger's samples from landing to lifting, in the key frames' coordinates.
    ///   - previousWords: Earlier words in the sentence, newest first.
    public func swipeWords(
        for path: [SwipeTouchSample],
        previousWords: [String],
        wordCase: SwipeWordCase,
        limit: Int
    ) throws -> [String] {
        let state = personalState()
        var words: [String] = []
        var seen: Set<String> = []
        for candidate in try swipeCandidates(for: path, previousWords: previousWords) where words.count < limit {
            let word = try written(
                candidate.spelling,
                wordCase: wordCase,
                previousWords: previousWords,
                state: (state.vocabulary, state.forms, state.learned)
            )
            if seen.insert(word).inserted {
                words.append(word)
            }
        }
        return words
    }

    /// The spellings `path` may have been swiped as, best first, as the bundled lexicon and the
    /// user's own words spell them, with how each ranks (`SwipeCandidateScoring`).
    /// - Parameter previousWords: Earlier words in the sentence, newest first.
    public func swipeCandidates(for path: [SwipeTouchSample], previousWords: [String]) throws -> [SwipeCandidate] {
        let state = personalState()
        let decoder = try swipeDecoding.decoder(for: engine.language)
        guard let emissions = decoder.emissions(for: path, keys: state.keys) else { return [] }
        let personal = try swipeDecoding.personalLexicon(
            Self.swipePersonalWords(vocabulary: state.vocabulary, learned: state.learned),
            decoder: decoder
        )
        let language = ContextLanguageScorer(engine: engine, vocabulary: state.vocabulary)
        return try decoder.candidates(
            emissions: emissions,
            personal: personal,
            contextLift: { spelling in try language.contextLift(of: spelling, previousWords: previousWords) },
            hasWordsBefore: previousWords.isEmpty == false
        )
    }

    /// The user's words a swipe can reach that the bundled lexicon may lack, as typing searches
    /// them (`setPersonalWords`): every word of their entries, names among them, the text
    /// replacement shortcuts, and the learned words the suggestion bar offers.
    static func swipePersonalWords(vocabulary: PersonalVocabulary, learned: LearnedVocabulary) -> [String] {
        let words = vocabulary.words
            + vocabulary.textReplacements.map(\.shortcut)
            + learned.keys.filter { learned.word($0)?.isOffered == true }
        return Array(Set(words)).sorted()
    }

    /// `spelling` written as typing writes the word when its letters are typed in `wordCase`
    /// (`replacement`, `suggestionForm`).
    private func written(
        _ spelling: String,
        wordCase: SwipeWordCase,
        previousWords: [String],
        state: (vocabulary: PersonalVocabulary, forms: PersonalWordForms, learned: LearnedVocabulary)
    ) throws -> String {
        if let expansion = state.vocabulary.expansion(for: spelling) {
            return expansion
        }
        let typed = wordCase.typed(spelling)
        let chosen: String
        if state.vocabulary.contains(spelling) {
            chosen = state.forms.written(typed, after: previousWords.first)
        } else if state.vocabulary.keepsAsTyped(spelling) {
            chosen = typed
        } else if let learnedWord = state.learned.word(spelling) {
            chosen = learnedWord.written(ofTyped: typed)
        } else {
            chosen = try suggestionForm(
                of: engine.capitalizedSpellings.written(spelling),
                previousWords: previousWords,
                learned: state.learned
            )
        }
        return casing.apply(of: typed, to: chosen)
    }
}
