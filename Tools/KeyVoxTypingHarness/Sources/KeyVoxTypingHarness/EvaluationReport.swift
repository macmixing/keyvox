/// Accumulated outcomes of one evaluation run and the rates derived from them.
struct EvaluationReport {
    private(set) var sentenceCount = 0
    private(set) var corrections: [CorrectionOutcome] = []
    private(set) var completions: [CompletionEvaluator.Outcome] = []
    private(set) var nextWords: [NextWordEvaluator.Outcome] = []
    private(set) var suggestionBars: [SuggestionBarEvaluator.Outcome] = []
    private(set) var correctionMilliseconds: [Double] = []
    var engineStartupMilliseconds = 0.0

    mutating func recordSentence() {
        sentenceCount += 1
    }

    mutating func record(_ outcome: CorrectionOutcome, milliseconds: Double) {
        corrections.append(outcome)
        correctionMilliseconds.append(milliseconds)
    }

    mutating func record(_ outcome: CompletionEvaluator.Outcome) {
        completions.append(outcome)
    }

    mutating func record(_ outcome: NextWordEvaluator.Outcome) {
        nextWords.append(outcome)
    }

    mutating func record(_ outcome: SuggestionBarEvaluator.Outcome) {
        suggestionBars.append(outcome)
    }

    func julyBarShowRate(withinLetters letters: Int) -> Double {
        let shown = suggestionBars.filter { ($0.lettersTypedWhenShownByJulyBar ?? .max) <= letters }
        return Self.rate(shown.count, of: suggestionBars.count)
    }

    func completionBarShowRate(withinLetters letters: Int) -> Double {
        let shown = suggestionBars.filter {
            ($0.lettersTypedWhenShownByCompletions ?? .max) <= letters
        }
        return Self.rate(shown.count, of: suggestionBars.count)
    }

    /// Share of words whose intended form showed in the July bar at any point while typing.
    var julyBarEverShownRate: Double {
        Self.rate(
            suggestionBars.filter { $0.lettersTypedWhenShownByJulyBar != nil }.count,
            of: suggestionBars.count
        )
    }

    func composedBarShowRate(withinLetters letters: Int) -> Double {
        let shown = suggestionBars.filter {
            ($0.lettersTypedWhenShownByComposedBar ?? .max) <= letters
        }
        return Self.rate(shown.count, of: suggestionBars.count)
    }

    var composedBarEverShownRate: Double {
        Self.rate(
            suggestionBars.filter { $0.lettersTypedWhenShownByComposedBar != nil }.count,
            of: suggestionBars.count
        )
    }

    var composedBarNonContinuationRate: Double {
        Self.rate(
            suggestionBars.reduce(0) { $0 + $1.midWordStepsComposedPrimaryNonContinuation },
            of: suggestionBars.reduce(0) { $0 + $1.midWordSteps }
        )
    }

    /// Keystroke savings when the user taps the bar as soon as it shows the intended word.
    func barKeystrokeSavings(lettersWhenShown: (SuggestionBarEvaluator.Outcome) -> Int?) -> Double {
        let baseline = suggestionBars.reduce(0) { $0 + $1.letterCount + 1 }
        let assisted = suggestionBars.reduce(0) { total, outcome in
            let shown = lettersWhenShown(outcome).map { min($0, outcome.letterCount) }
            return total + (shown.map { $0 + 1 } ?? outcome.letterCount + 1)
        }
        guard baseline > 0 else { return 0 }
        return 1 - Double(assisted) / Double(baseline)
    }

    var completionBarEverShownRate: Double {
        Self.rate(
            suggestionBars.filter { $0.lettersTypedWhenShownByCompletions != nil }.count,
            of: suggestionBars.count
        )
    }

    /// Share of mid-word moments where the July bar's first slot did not begin with the
    /// intended word's letters so far.
    var julyBarNonContinuationRate: Double {
        Self.rate(
            suggestionBars.reduce(0) { $0 + $1.midWordStepsLeadingWithNonContinuation },
            of: suggestionBars.reduce(0) { $0 + $1.midWordSteps }
        )
    }

    func corrections(of kind: CorrectionOutcome.TypingKind) -> [CorrectionOutcome] {
        corrections.filter { $0.typingKind == kind }
    }

    /// Share of all words that end up exactly as intended after space.
    var finalWordAccuracy: Double {
        Self.rate(corrections.filter(\.isFinalWordCorrect).count, of: corrections.count)
    }

    /// Share of all words that would be right with autocorrect switched off.
    var uncorrectedWordAccuracy: Double {
        Self.rate(corrections.filter { $0.typingKind == .exact }.count, of: corrections.count)
    }

    /// Standard keystroke savings: taps saved by accepting an offered completion
    /// (one tap inserts the word and its space) over typing every letter plus space.
    var completionKeystrokeSavings: Double {
        let baseline = completions.reduce(0) { $0 + $1.letterCount + 1 }
        let assisted = completions.reduce(0) { total, outcome in
            total + (outcome.lettersTypedWhenOffered.map { $0 + 1 } ?? outcome.letterCount + 1)
        }
        guard baseline > 0 else { return 0 }
        return 1 - Double(assisted) / Double(baseline)
    }

    func completionOfferRate(withinLetters letters: Int) -> Double {
        let offered = completions.filter { ($0.lettersTypedWhenOffered ?? .max) <= letters }
        return Self.rate(offered.count, of: completions.count)
    }

    func nextWordRate(withinRank rank: Int) -> Double {
        Self.rate(nextWords.filter { ($0.rank ?? .max) <= rank }.count, of: nextWords.count)
    }

    func correctionLatency(percentile: Double) -> Double {
        guard correctionMilliseconds.isEmpty == false else { return 0 }
        let sorted = correctionMilliseconds.sorted()
        let index = Int((Double(sorted.count - 1) * percentile).rounded())
        return sorted[index]
    }

    static func rate(_ count: Int, of total: Int) -> Double {
        total == 0 ? 0 : Double(count) / Double(total)
    }
}
