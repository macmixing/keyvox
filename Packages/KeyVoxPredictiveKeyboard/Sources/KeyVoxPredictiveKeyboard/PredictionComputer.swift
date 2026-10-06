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
    public func updateVocabulary(_ vocabulary: PersonalVocabulary) {
        lock.lock()
        self.vocabulary = vocabulary
        lock.unlock()
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
                bar: try nextWordBar(for: request, ranker: ranker),
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
        let personalCandidates = vocabulary.candidates(near: typed)
        let corrector = NoisyChannelCorrector(parameters: parameters, keys: keys, language: language)
        let decision = try corrector.decide(
            typedWord: typed,
            touches: request.touches,
            previousWords: request.previousWords,
            candidates: correction.suggestions.map(\.word) + personalCandidates
        )
        let ranked = try ranker.rank(
            typedWord: typed,
            touches: request.touches,
            previousWords: request.previousWords,
            candidates: completion.suggestions.map(\.word)
                + correction.suggestions.map(\.word)
                + personalCandidates
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

    /// Text replacements always expand; personal words and words the user kept are never
    /// replaced; otherwise the grammatical fix or the corrector's choice applies.
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
        if let grammatical = EnglishAutomaticCorrectionPolicy.grammaticalReplacement(for: typed) {
            return grammatical
        }
        return decision.replacement.map { WordCasing.apply(of: typed, to: $0) }
    }

    private func nextWordBar(
        for request: PredictionRequest,
        ranker: SuggestionCandidateRanker
    ) throws -> SuggestionBar {
        guard request.previousWords.isEmpty == false else { return .empty }
        let response = try engine.predict(
            typedWord: "",
            previousWords: request.previousWords,
            touches: [],
            mode: .nextWord
        )
        let ranked = try ranker.rankNextWords(
            previousWords: request.previousWords,
            candidates: response.suggestions.map(\.word)
        )
        return SuggestionBarComposer.composeNextWords(ranked.map(\.word))
    }
}
