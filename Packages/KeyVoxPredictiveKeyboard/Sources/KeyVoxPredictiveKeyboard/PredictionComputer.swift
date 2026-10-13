import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Computes suggestions and the space-bar autocorrection for a prediction request.
/// Safe to call from any thread; the engine serializes its own native work.
public final class PredictionComputer: @unchecked Sendable {
    private let engine: EnglishPredictiveEngine
    private let parameters: NoisyChannelCorrector.Parameters
    private let lock = NSLock()
    /// How much likelier than usual the words before must make a dictionary word for the bar to
    /// keep it as the dictionary writes it rather than with the capitals the user gave it, as the
    /// natural log of the ratio (`suggestionForm`): half again as likely. Measured against the
    /// system keyboard after the user wrote "Rose" (Tools/AppleKeyboardBaseline): it kept "rose"
    /// after words that make it 1.7 to 51 times likelier ("the", "a", "red"), and offered "Rose"
    /// after words at 1.4 times or less ("and", "with", "like").
    static let everydayWordContextLogLift = log(1.5)
    private var keys: KeyCenterMap
    private var vocabulary = PersonalVocabulary.empty
    private var forms = PersonalWordForms.empty
    private var learned = LearnedVocabulary.empty

    public init(
        engine: EnglishPredictiveEngine,
        parameters: NoisyChannelCorrector.Parameters = NoisyChannelCorrector.standardParameters
    ) {
        self.engine = engine
        self.parameters = parameters
        keys = KeyCenterMap(geometry: EnglishKeyboardLayout.defaultGeometry)
    }

    /// Call whenever the letter keys move or resize.
    public func updateKeyboardGeometry(_ geometry: [PredictionKeyGeometry], keyboardSize: CGSize) {
        guard engine.updateKeyboardGeometry(geometry, keyboardSize: keyboardSize) else { return }
        lock.lock()
        keys = KeyCenterMap(geometry: geometry)
        lock.unlock()
    }

    /// Call whenever the user's dictionary, contacts, or text replacements change. Known
    /// names the dictionary also has as everyday lowercase words ("Care", "OLD") are only kept
    /// as typed, as the system keyboard keeps them; known names that are dictionary words
    /// written without their apostrophe ("Dont") are left out, so typing one is corrected like
    /// any common word; the rest are used like one-word entries. Such a word in an entry phrase
    /// is ordinary typing on its own too.
    public func updateVocabulary(_ givenVocabulary: PersonalVocabulary) throws {
        var names: [String] = []
        var commonWords: [String] = []
        for name in givenVocabulary.knownNames {
            if engine.capitalizedSpellings.spelling(of: name) != nil {
                names.append(name)
            } else if try engine.analyze(word: name).wordIsValid {
                continue
            } else if try missesItsApostrophe(name) {
                commonWords.append(name)
            } else {
                names.append(name)
            }
        }
        let withNames = givenVocabulary.droppingKnownNames(commonWords).addingNamesAsEntries(names)
        var everydayWords: Set<String> = []
        var ordinaryWords: [String] = []
        for word in withNames.phraseWords {
            if try engine.analyze(word: word).wordIsValid {
                everydayWords.insert(word)
            } else if try missesItsApostrophe(word) {
                ordinaryWords.append(word)
            }
        }
        let vocabulary = withNames.treatingPhraseWordsAsOrdinary(ordinaryWords)
        let forms = PersonalWordForms(vocabulary: vocabulary, everydayWords: everydayWords)
        lock.lock()
        self.vocabulary = vocabulary
        self.forms = forms
        let learned = learned
        lock.unlock()
        try searchPersonalWords(vocabulary: vocabulary, learned: learned)
    }

    /// Whether `word` is a dictionary word written without its apostrophe, as "dont" is.
    private func missesItsApostrophe(_ word: String) throws -> Bool {
        let letters = Array(PersonalVocabulary.key(word))
        guard letters.count > 1, letters.contains("'") == false else { return false }
        for index in 1..<letters.count {
            if try engine.analyze(word: String(letters[..<index]) + "'" + String(letters[index...])).wordIsValid {
                return true
            }
        }
        return false
    }

    /// Call whenever what the keyboard learned from the user's typing changes.
    public func updateLearnedWords(_ learned: LearnedVocabulary) throws {
        lock.lock()
        self.learned = learned
        let vocabulary = vocabulary
        lock.unlock()
        try searchPersonalWords(vocabulary: vocabulary, learned: learned)
    }

    /// Searched in lowercase; `PersonalWordForms` and `LearnedVocabulary` decide how the words
    /// are written.
    private func searchPersonalWords(vocabulary: PersonalVocabulary, learned: LearnedVocabulary) throws {
        try engine.setPersonalWords(Array(Set(vocabulary.words.map(PersonalVocabulary.key) + learned.keys)).sorted())
    }

    public func compute(_ request: PredictionRequest) throws -> PredictionResult {
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
        let forms = forms
        let learned = learned
        lock.unlock()
        let language = ContextLanguageScorer(engine: engine, vocabulary: vocabulary)
        let ranker = SuggestionCandidateRanker(parameters: parameters, keys: keys, language: language)

        guard request.currentWord.isEmpty == false else {
            return PredictionResult(
                request: request,
                bar: request.offersNextWords
                    ? try nextWordBar(for: request, vocabulary: vocabulary, learned: learned, ranker: ranker)
                    : .empty,
                autocorrection: nil
            )
        }

        let typed = request.currentWord.replacingOccurrences(of: "’", with: "'")
        let engineTouches = request.touches.map(PredictionTouch.init(location:))
        let completion = try engine.predict(
            typedWord: typed,
            previousWords: request.previousWords,
            touches: engineTouches,
            mode: .completion
        )
        let correction = try engine.predict(
            typedWord: typed,
            previousWords: request.previousWords,
            touches: engineTouches,
            mode: .correction
        )
        let personalSuggestions = try engine.personalSuggestions(
            typedWord: typed,
            touches: engineTouches
        )
        let personalCandidates = personalSuggestions.filter { vocabulary.contains($0) }
        let learnedCandidates = personalSuggestions.filter { vocabulary.contains($0) == false && learned.word($0)?.isOffered == true }
        let corrector = NoisyChannelCorrector(parameters: parameters, keys: keys, language: language)
        let decision = try corrector.decide(
            typedWord: typed,
            touches: request.touches,
            previousWords: request.previousWords,
            candidates: written(
                correction.suggestions.map(\.word) + personalCandidates,
                after: request.previousWords.first,
                vocabulary: vocabulary,
                forms: forms
            )
        )
        let ranked = try ranker.rank(
            typedWord: typed,
            touches: request.touches,
            previousWords: request.previousWords,
            candidates: written(
                completion.suggestions.map(\.word)
                    + correction.suggestions.map(\.word)
                    + personalCandidates,
                after: request.previousWords.first,
                vocabulary: vocabulary,
                forms: forms
            )
        )

        let split = try missingSpaceSplit(
            typed: typed,
            readings: correction.twoWordSuggestions,
            request: request,
            vocabulary: vocabulary,
            learned: learned,
            decision: decision,
            keys: keys,
            language: language
        )
        let replacement = replacement(
            typed: typed,
            request: request,
            vocabulary: vocabulary,
            forms: forms,
            learned: learned,
            decision: decision,
            ranked: ranked,
            split: split
        ).flatMap { request.heldBackCorrections.contains(PersonalVocabulary.key($0)) ? nil : $0 }
        let suggested = try suggestedWords(
            ranked: ranked.map(\.word),
            learnedCandidates: learnedCandidates,
            request: request,
            learned: learned
        )
        // Where a learned word comes first, space leaves the typed letters alone, as on the
        // system keyboard; it may still expand a text replacement or fix capitals.
        let autocorrection = suggested.leadsWithLearnedWord && vocabulary.expansion(for: typed) == nil
            ? replacement.flatMap { $0.lowercased() == typed.lowercased() ? $0 : nil }
            : replacement
        let isUsersWord = vocabulary.contains(typed) || vocabulary.expansion(for: typed) != nil
        return PredictionResult(
            request: request,
            bar: request.revertibleText.map(SuggestionBarComposer.composeRevert) ?? SuggestionBarComposer.compose(
                typedWord: typed,
                autocorrection: autocorrection,
                rankedWords: suggested.words.map { WordCasing.apply(of: typed, to: $0) }
            ),
            autocorrection: autocorrection,
            typedWordKind: isUsersWord ? .usersWord
                : decision.typed.language.isDictionaryWord && learned.word(typed) == nil ? .dictionaryWord
                : .unknown
        )
    }

    /// The words the bar offers while a word is typed, best first: learned words that often
    /// follow the word before, the ranked words in the user's capitals where the user gave a
    /// dictionary word capitals and the words before do not call for the everyday word, and then
    /// the other learned words, as the user first wrote them; and whether a learned word leads.
    private func suggestedWords(
        ranked: [String],
        learnedCandidates: [String],
        request: PredictionRequest,
        learned: LearnedVocabulary
    ) throws -> (words: [String], leadsWithLearnedWord: Bool) {
        let previous = request.isAtSentenceStart
            ? ContextLanguageScorer.sentenceStart
            : request.previousWords.first.map(PersonalVocabulary.key) ?? ContextLanguageScorer.sentenceStart
        let learnedWords = learnedCandidates.compactMap(learned.word)
        let first = learnedWords.filter { $0.oftenFollowed.contains(previous) }.map(\.suggestedForm)
        let later = learnedWords.filter { $0.oftenFollowed.contains(previous) == false }.map(\.suggestedForm)
        let words = try first + ranked.map { try suggestionForm(of: $0, previousWords: request.previousWords, learned: learned) } + later
        return (words, first.isEmpty == false)
    }

    /// How the bar writes the dictionary word `word` after `previousWords`: the user's capitals
    /// when they gave it capitals, unless the words before make the everyday word much likelier
    /// than usual ("a red rose"), as the system keyboard keeps it there.
    private func suggestionForm(of word: String, previousWords: [String], learned: LearnedVocabulary) throws -> String {
        guard let capitalForm = learned.capitalForm(of: word), word == word.lowercased() else { return word }
        let analysis = try engine.analyze(word: word, previousWords: previousWords)
        let lift = analysis.precedingPairObserved
            ? analysis.precedingLogProbability - analysis.unigramLogProbability
            : -.infinity
        return lift >= Self.everydayWordContextLogLift ? word : capitalForm
    }

    /// What should replace a word the user finished as typed, now that the word after it is
    /// known, or nil to leave it. A word that starts one of the user's phrases takes the
    /// phrase's capitals once the phrase's next word follows; the user's words are otherwise
    /// left alone, as are corrections the user turned down.
    public func revision(for request: RevisionRequest) throws -> String? {
        try proposedRevision(for: request).flatMap {
            request.heldBackCorrections.contains(PersonalVocabulary.key($0)) ? nil : $0
        }
    }

    private func proposedRevision(for request: RevisionRequest) throws -> String? {
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
        let forms = forms
        let learned = learned
        lock.unlock()
        let typed = request.word.replacingOccurrences(of: "’", with: "'")
        if let phraseStart = vocabulary.phraseForm(of: typed, before: request.followingWord) {
            let written = WordCasing.apply(of: typed, to: phraseStart)
            return written == typed ? nil : written
        }
        guard vocabulary.contains(typed) == false, vocabulary.keepsAsTyped(typed) == false,
              learned.word(typed) == nil else { return nil }
        let engineTouches = request.touches.map(PredictionTouch.init(location:))
        let correction = try engine.predict(
            typedWord: typed,
            previousWords: request.previousWords,
            touches: engineTouches,
            mode: .correction
        )
        let personalCandidates = try engine.personalSuggestions(typedWord: typed, touches: engineTouches)
            .filter { vocabulary.contains($0) }
        let corrector = NoisyChannelCorrector(
            parameters: parameters,
            keys: keys,
            language: ContextLanguageScorer(engine: engine, vocabulary: vocabulary)
        )
        let decision = try corrector.decide(
            typedWord: typed,
            touches: request.touches,
            previousWords: request.previousWords,
            followingWord: request.followingWord,
            candidates: written(
                correction.suggestions.map(\.word) + personalCandidates,
                after: request.previousWords.first,
                vocabulary: vocabulary,
                forms: forms
            )
        )
        return decision.replacement.map { WordCasing.apply(of: typed, to: $0) }
    }

    /// The letter a tap on a non-letter key was meant for, or nil to keep that key.
    /// - Parameter otherKeyFrame: The frame of the key the touch hit, in the same
    ///   coordinates as the letter key geometry.
    public func intendedLetter(
        forTapAt touch: CGPoint,
        onKeyWithFrame otherKeyFrame: CGRect,
        otherKey: ContestedTap.OtherKey,
        request: PredictionRequest,
        policy: ContestedTapPolicy
    ) throws -> Character? {
        let typed = request.currentWord.replacingOccurrences(of: "’", with: "'").lowercased()
        let landedOnOtherKey = otherKeyFrame.contains(touch)
        if policy.keepsOtherKey(startsWord: typed.isEmpty, landedOnOtherKey: landedOnOtherKey) {
            return nil
        }
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
        lock.unlock()
        let nearby = keys.letters(near: touch, within: policy.maximumDistance(for: otherKey))
        guard nearby.isEmpty == false else { return nil }
        let language = ContextLanguageScorer(engine: engine, vocabulary: vocabulary)

        var letters: [ContestedTap.Letter] = []
        for (letter, distance) in nearby {
            let prefix = typed + String(letter)
            // The likeliest words under the exact letters, not a typo-tolerant prediction: the
            // tap is waiting on this, and only words that start with the letters count.
            let completions = try engine.likeliestWords(startingWith: prefix, limit: 8)
                + engine.personalSuggestions(typedWord: prefix, touches: [])
                + [prefix]
            var continuation: Double?
            for word in completions where word.lowercased().hasPrefix(prefix) {
                let score = try language.score(of: word, previousWords: request.previousWords)
                guard score.isDictionaryWord else { continue }
                continuation = max(continuation ?? -.infinity, score.logProbability)
            }
            if let continuation {
                letters.append(ContestedTap.Letter(
                    letter: letter,
                    distance: distance,
                    continuationLogProbability: continuation
                ))
            }
        }

        var ending: Double?
        if typed.isEmpty == false {
            let score = try language.score(of: typed, previousWords: request.previousWords)
            ending = score.isDictionaryWord ? score.logProbability : nil
        }
        return policy.intendedLetter(for: ContestedTap(
            otherKey: otherKey,
            landedOnOtherKey: landedOnOtherKey,
            startsWord: typed.isEmpty,
            letters: letters,
            endingLogProbability: ending
        ))
    }

    /// Text replacements always expand; words the cursor is in and known names are never
    /// replaced, and the user's words are only ever written the user's way. A learned word is
    /// left as typed, with the user's capitals once they write it with them (`LearnedWords`). A
    /// typed word the dictionary lacks becomes the best suggestion when that is one of the
    /// user's words it begins, as the system keyboard completes a contact's name. Otherwise the
    /// corrector's choice, or the typed word itself, is spelled with its capitals when it
    /// has them, with the typed capitalization, and with a capital pronoun "I" ("i'm"
    /// becomes "I'm").
    private func replacement(
        typed: String,
        request: PredictionRequest,
        vocabulary: PersonalVocabulary,
        forms: PersonalWordForms,
        learned: LearnedVocabulary,
        decision: NoisyChannelCorrector.Decision,
        ranked: [SuggestionCandidateRanker.RankedWord],
        split: MissingSpaceCorrector.Split?
    ) -> String? {
        guard request.keepsTypedWord == false else { return nil }
        if let expansion = vocabulary.expansion(for: typed) {
            return expansion
        }
        if let split {
            let left = WordCasing.apply(of: typed, to: engine.capitalizedSpellings.written(split.left))
            let right = WordCasing.capitalizingPronoun(
                WordCasing.carryingAllCapitals(of: typed, to: engine.capitalizedSpellings.written(split.right))
            )
            return left + " " + right
        }
        let chosen: String
        if vocabulary.contains(typed) {
            chosen = forms.written(typed, after: request.previousWords.first)
        } else if vocabulary.keepsAsTyped(typed) {
            chosen = typed
        } else if let learnedWord = learned.word(typed) {
            chosen = learnedWord.written(ofTyped: typed)
        } else if decision.typed.language.isDictionaryWord == false
                    || decision.typed.language.isEverydayWord,
                  let best = ranked.first?.word,
                  vocabulary.contains(best),
                  PersonalVocabulary.key(best).hasPrefix(PersonalVocabulary.key(typed)),
                  fitsAsWellAsCorrection(best, decision: decision) {
            chosen = best
        } else {
            chosen = decision.replacement ?? engine.capitalizedSpellings.written(typed)
        }
        let written = WordCasing.apply(of: typed, to: chosen)
        return written == typed ? nil : written
    }

    /// Whether the user's word `word`, which the typed letters begin, fits the words before at
    /// least as well as the word `decision` would correct the typing to, so space completes it
    /// only then. Measured against the system keyboard (Tools/AppleKeyboardBaseline): contact
    /// names typed partly after 17 different words were completed only where the everyday word the
    /// letters were also a typo of fit the words before less well.
    private func fitsAsWellAsCorrection(_ word: String, decision: NoisyChannelCorrector.Decision) -> Bool {
        let wordKey = PersonalVocabulary.key(word)
        guard let replacement = decision.replacement.map(PersonalVocabulary.key), replacement != wordKey,
              let correction = decision.rankedAlternatives.first(where: { PersonalVocabulary.key($0.word) == replacement }),
              let completion = decision.rankedAlternatives.first(where: { PersonalVocabulary.key($0.word) == wordKey }) else {
            return true
        }
        return completion.language.logProbability >= correction.language.logProbability
    }

    /// The likeliest next words, or, after a word the bundled data has nothing to follow, such as
    /// a name or a learned word, what usually follows such a word after the word before it
    /// (`UnknownWordFollowers`), as the system keyboard never leaves the bar empty there. Words
    /// that would repeat what the user picked from the bar in a row come after the others
    /// (`RepeatedPicks`), and which of the about equally likely others leads depends on those
    /// picks (`PickVariety`).
    private func nextWordBar(
        for request: PredictionRequest,
        vocabulary: PersonalVocabulary,
        learned: LearnedVocabulary,
        ranker: SuggestionCandidateRanker
    ) throws -> SuggestionBar {
        guard let previousWord = request.previousWords.first else {
            let openers = engine.sentenceOpeners.words(after: request.previousSentence).map { word in
                let written = engine.capitalizedSpellings.written(word)
                return written == word ? WordCasing.startingSentence(word) : written
            }
            return SuggestionBarComposer.composeNextWords(openers)
        }
        let response = try engine.predict(
            typedWord: "",
            previousWords: request.previousWords,
            touches: [],
            mode: .nextWord
        )
        // While the user picks the bar's words in a row, the words that most often follow the last
        // word join the dictionary's few, so the picks do not run out of new words.
        let followers = request.pickedWords.isEmpty ? [] : engine.wordFollowers.words(after: previousWord)
        let scored = try ranker.rankNextWords(
            previousWords: request.previousWords,
            candidates: vocabulary.continuations(after: previousWord)
                + (response.suggestions.map(\.word) + followers).map { engine.capitalizedSpellings.written($0) }
        )
        let picks = RepeatedPicks(pickedWords: request.pickedWords, grammarWords: engine.grammarWords)
        let ranked: [String]
        if scored.isEmpty {
            ranked = picks.ordering(
                engine.unknownWordFollowers
                    .words(afterUnknownWordFollowing: request.previousWords.dropFirst().first)
                    .map { engine.capitalizedSpellings.written($0) },
                after: request.previousWords
            )
        } else {
            let fresh = scored.filter { picks.repeats($0.word, after: request.previousWords) == false }
            ranked = PickVariety(pickedWords: request.pickedWords, pickRun: request.pickRun).ordering(fresh)
                + scored.filter { picks.repeats($0.word, after: request.previousWords) }.map(\.word)
        }
        return SuggestionBarComposer.composeNextWords(try ranked.map {
            WordCasing.capitalizingPronoun(try suggestionForm(of: $0, previousWords: request.previousWords, learned: learned))
        })
    }

    /// Candidates written the user's way when they are the user's words, and otherwise spelled
    /// with their capitals when they have them.
    private func written(
        _ words: [String],
        after previousWord: String?,
        vocabulary: PersonalVocabulary,
        forms: PersonalWordForms
    ) -> [String] {
        words.map { word in
            vocabulary.contains(word)
                ? forms.written(word, after: previousWord)
                : engine.capitalizedSpellings.written(word)
        }
    }

    /// The two words a typed word the dictionary does not know was meant as, when that reads
    /// clearly better than any one word; the user's own words and learned words are never split.
    private func missingSpaceSplit(
        typed: String,
        readings: [String],
        request: PredictionRequest,
        vocabulary: PersonalVocabulary,
        learned: LearnedVocabulary,
        decision: NoisyChannelCorrector.Decision,
        keys: KeyCenterMap,
        language: ContextLanguageScorer
    ) throws -> MissingSpaceCorrector.Split? {
        guard request.keepsTypedWord == false,
              decision.typed.language.isDictionaryWord == false,
              vocabulary.expansion(for: typed) == nil,
              vocabulary.contains(typed) == false,
              vocabulary.keepsAsTyped(typed) == false,
              learned.word(typed) == nil else { return nil }
        return try MissingSpaceCorrector(parameters: parameters, keys: keys, language: language).split(
            of: readings,
            touches: request.touches,
            previousWords: request.previousWords,
            decision: decision
        )
    }
}
