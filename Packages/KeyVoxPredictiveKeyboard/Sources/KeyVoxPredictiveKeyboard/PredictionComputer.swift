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

    /// Call whenever the user's dictionary, contacts, or text replacements change.
    public func updateVocabulary(_ vocabulary: PersonalVocabulary) throws {
        lock.lock()
        self.vocabulary = vocabulary
        lock.unlock()
        try engine.setPersonalWords(vocabulary.words)
    }

    public func compute(_ request: PredictionRequest) throws -> PredictionResult {
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
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
            candidates: vocabulary.writtenForms(of: correction.suggestions.map(\.word) + personalCandidates)
        )
        let ranked = try ranker.rank(
            typedWord: typed,
            touches: request.touches,
            previousWords: request.previousWords,
            candidates: vocabulary.writtenForms(
                of: completion.suggestions.map(\.word)
                    + correction.suggestions.map(\.word)
                    + personalCandidates
            )
        )

        let replacement = Self.replacement(
            typed: typed,
            request: request,
            vocabulary: vocabulary,
            decision: decision
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
    /// known, or nil to leave it. The user's own words are always left alone.
    public func revision(for request: RevisionRequest) throws -> String? {
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
        lock.unlock()
        let typed = request.word.replacingOccurrences(of: "’", with: "'")
        guard vocabulary.contains(typed) == false else { return nil }
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
            candidates: vocabulary.writtenForms(of: correction.suggestions.map(\.word) + personalCandidates)
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
        lock.lock()
        let keys = keys
        let vocabulary = vocabulary
        lock.unlock()
        let nearby = keys.letters(near: touch, within: policy.parameters.maximumDistance)
        guard nearby.isEmpty == false else { return nil }
        let language = ContextLanguageScorer(engine: engine, vocabulary: vocabulary)
        let typed = request.currentWord.replacingOccurrences(of: "’", with: "'").lowercased()

        var letters: [ContestedTap.Letter] = []
        for (letter, distance) in nearby {
            let prefix = typed + String(letter)
            let completions = try engine.predict(
                typedWord: prefix,
                previousWords: request.previousWords,
                touches: [],
                mode: .completion
            ).suggestions.map(\.word)
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
            landedOnOtherKey: otherKeyFrame.contains(touch),
            startsWord: typed.isEmpty,
            letters: letters,
            endingLogProbability: ending
        ))
    }

    /// Text replacements always expand; personal words and words the user kept are never
    /// replaced; otherwise the corrector's choice, or the typed word itself, is written
    /// with the typed capitalization and a capital pronoun "I" ("i'm" becomes "I'm").
    private static func replacement(
        typed: String,
        request: PredictionRequest,
        vocabulary: PersonalVocabulary,
        decision: NoisyChannelCorrector.Decision
    ) -> String? {
        guard request.keepsTypedWord == false else { return nil }
        if let expansion = vocabulary.expansion(for: typed) {
            return expansion
        }
        guard vocabulary.contains(typed) == false else { return nil }
        let written = WordCasing.apply(of: typed, to: decision.replacement ?? typed)
        return written == typed ? nil : written
    }

    private func nextWordBar(
        for request: PredictionRequest,
        vocabulary: PersonalVocabulary,
        ranker: SuggestionCandidateRanker
    ) throws -> SuggestionBar {
        guard let previousWord = request.previousWords.first else { return .empty }
        let response = try engine.predict(
            typedWord: "",
            previousWords: request.previousWords,
            touches: [],
            mode: .nextWord
        )
        let ranked = try ranker.rankNextWords(
            previousWords: request.previousWords,
            candidates: vocabulary.continuations(after: previousWord)
                + response.suggestions.map(\.word)
        )
        return SuggestionBarComposer.composeNextWords(ranked.map { WordCasing.capitalizingPronoun($0.word) })
    }
}
