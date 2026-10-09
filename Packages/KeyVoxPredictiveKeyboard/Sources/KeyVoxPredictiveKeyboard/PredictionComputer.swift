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
    private var keys: KeyCenterMap
    private var vocabulary = PersonalVocabulary.empty
    private var forms = PersonalWordForms.empty

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
    /// as typed, as the system keyboard keeps them; the rest are used like one-word entries.
    public func updateVocabulary(_ givenVocabulary: PersonalVocabulary) throws {
        var names: [String] = []
        for name in givenVocabulary.knownNames {
            let isDictionaryWord = try engine.analyze(word: name).wordIsValid
            if engine.capitalizedSpellings.spelling(of: name) != nil || isDictionaryWord == false {
                names.append(name)
            }
        }
        let vocabulary = givenVocabulary.addingNamesAsEntries(names)
        var everydayWords: Set<String> = []
        for word in vocabulary.phraseWords where try engine.analyze(word: word).wordIsValid {
            everydayWords.insert(word)
        }
        let forms = PersonalWordForms(vocabulary: vocabulary, everydayWords: everydayWords)
        lock.lock()
        self.vocabulary = vocabulary
        self.forms = forms
        lock.unlock()
        // Searched in lowercase; `PersonalWordForms` decides how the words are written.
        try engine.setPersonalWords(vocabulary.words.map(PersonalVocabulary.key))
    }

    public func compute(_ request: PredictionRequest) throws -> PredictionResult {
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
        let forms = forms
        lock.unlock()
        let language = ContextLanguageScorer(engine: engine, vocabulary: vocabulary)
        let ranker = SuggestionCandidateRanker(parameters: parameters, keys: keys, language: language)

        guard request.currentWord.isEmpty == false else {
            return PredictionResult(
                request: request,
                bar: try nextWordBar(for: request, vocabulary: vocabulary, ranker: ranker),
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
        let personalCandidates = try engine.personalSuggestions(
            typedWord: typed,
            touches: engineTouches
        )
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
            decision: decision,
            keys: keys,
            language: language
        )
        let replacement = replacement(
            typed: typed,
            request: request,
            vocabulary: vocabulary,
            forms: forms,
            decision: decision,
            ranked: ranked,
            split: split
        )
        return PredictionResult(
            request: request,
            bar: SuggestionBarComposer.compose(
                typedWord: typed,
                autocorrection: replacement,
                rankedWords: ranked.map { WordCasing.apply(of: typed, to: $0.word) }
            ),
            autocorrection: replacement
        )
    }

    /// What should replace a word the user finished as typed, now that the word after it is
    /// known, or nil to leave it. A word that starts one of the user's phrases takes the
    /// phrase's capitals once the phrase's next word follows; the user's words are otherwise
    /// left alone.
    public func revision(for request: RevisionRequest) throws -> String? {
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
        let forms = forms
        lock.unlock()
        let typed = request.word.replacingOccurrences(of: "’", with: "'")
        if let phraseStart = vocabulary.phraseForm(of: typed, before: request.followingWord) {
            let written = WordCasing.apply(of: typed, to: phraseStart)
            return written == typed ? nil : written
        }
        guard vocabulary.contains(typed) == false, vocabulary.keepsAsTyped(typed) == false else { return nil }
        let engineTouches = request.touches.map(PredictionTouch.init(location:))
        let correction = try engine.predict(
            typedWord: typed,
            previousWords: request.previousWords,
            touches: engineTouches,
            mode: .correction
        )
        let personalCandidates = try engine.personalSuggestions(typedWord: typed, touches: engineTouches)
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

    /// Text replacements always expand; words the user kept and known names are never
    /// replaced, and the user's words are only ever written the user's way. A typed word
    /// the dictionary lacks becomes the best suggestion when that is one of the user's
    /// words it begins, as the system keyboard completes a contact's name. Otherwise the
    /// corrector's choice, or the typed word itself, is spelled with its capitals when it
    /// has them, with the typed capitalization, and with a capital pronoun "I" ("i'm"
    /// becomes "I'm").
    private func replacement(
        typed: String,
        request: PredictionRequest,
        vocabulary: PersonalVocabulary,
        forms: PersonalWordForms,
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
            let right = WordCasing.capitalizingPronoun(engine.capitalizedSpellings.written(split.right))
            return left + " " + right
        }
        let chosen: String
        if vocabulary.contains(typed) {
            chosen = forms.written(typed, after: request.previousWords.first)
        } else if vocabulary.keepsAsTyped(typed) {
            chosen = typed
        } else if decision.typed.language.isDictionaryWord == false
                    || decision.typed.language.isEverydayWord,
                  let best = ranked.first?.word,
                  vocabulary.contains(best),
                  PersonalVocabulary.key(best).hasPrefix(PersonalVocabulary.key(typed)) {
            chosen = best
        } else {
            chosen = decision.replacement ?? engine.capitalizedSpellings.written(typed)
        }
        let written = WordCasing.apply(of: typed, to: chosen)
        return written == typed ? nil : written
    }

    private func nextWordBar(
        for request: PredictionRequest,
        vocabulary: PersonalVocabulary,
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
        let ranked = try ranker.rankNextWords(
            previousWords: request.previousWords,
            candidates: vocabulary.continuations(after: previousWord)
                + response.suggestions.map { engine.capitalizedSpellings.written($0.word) }
        )
        return SuggestionBarComposer.composeNextWords(ranked.map { WordCasing.capitalizingPronoun($0.word) })
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
    /// clearly better than any one word; the user's own words are never split.
    private func missingSpaceSplit(
        typed: String,
        readings: [String],
        request: PredictionRequest,
        vocabulary: PersonalVocabulary,
        decision: NoisyChannelCorrector.Decision,
        keys: KeyCenterMap,
        language: ContextLanguageScorer
    ) throws -> MissingSpaceCorrector.Split? {
        guard request.keepsTypedWord == false,
              decision.typed.language.isDictionaryWord == false,
              vocabulary.expansion(for: typed) == nil,
              vocabulary.contains(typed) == false,
              vocabulary.keepsAsTyped(typed) == false else { return nil }
        return try MissingSpaceCorrector(parameters: parameters, keys: keys, language: language).split(
            of: readings,
            touches: request.touches,
            previousWords: request.previousWords,
            decision: decision
        )
    }
}
