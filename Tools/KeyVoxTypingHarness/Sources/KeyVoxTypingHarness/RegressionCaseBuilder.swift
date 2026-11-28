import Foundation
import KeyVoxPredictiveKeyboard
import KeyVoxTypingSimulation

/// Builds a typing language's regression cases (`regression-cases`): sentences of the corpus
/// whose every word its keys type and the language's dictionary offers, or, for a word holding a
/// letter no key types, which a language may keep beside its dictionary, that the sentence writes
/// in lowercase, so never a name. A quarter of them have a word holding a letter no key types,
/// typed as its plain letter for autocorrection to restore, and a quarter an apostrophe, where
/// the corpus has enough; the rest are any. Every
/// tapped letter gets a Gaussian finger offset, and each case records the suggestion bar after
/// the space before one word and partway through two others.
enum RegressionCaseBuilder {
    private static let wordCounts = 3...8
    /// Offsets are rounded to this many steps per key pitch, so the cases read plainly.
    private static let offsetSteps = 1_000.0
    private static let completionBarCount = 2

    private struct Candidate {
        let intended: [String]
        let tapped: [String]
        let hasPlainTypedLetter: Bool
        let hasApostrophe: Bool
    }

    static func build(
        languageIdentifier: String,
        corpusPaths: [String],
        caseCount: Int,
        noiseInKeyPitches: Double,
        seed: UInt64
    ) throws -> [TypingRegressionCase] {
        let language = try TypingLanguage.bundled(identifier: languageIdentifier)
        let layout = KeyboardLayoutModel(language: language)
        let offered = Set(try PredictiveEngine(language: language).dictionaryWords()
            .filter(\.isOfferable)
            .map { $0.spelling.lowercased() })

        var shuffleGenerator = SeededRandomGenerator(seed: seed ^ 0x5EED)
        let candidates = try CorpusLoader.sentences(from: corpusPaths)
            .compactMap { candidate(for: $0, layout: layout, offered: offered) }
            .shuffled(using: &shuffleGenerator)

        let quota = caseCount / 4
        var chosen: [Int] = []
        for wanted in [\Candidate.hasPlainTypedLetter, \Candidate.hasApostrophe] {
            chosen += candidates.indices
                .filter { candidates[$0][keyPath: wanted] && chosen.contains($0) == false }
                .prefix(quota)
        }
        chosen += candidates.indices.filter { chosen.contains($0) == false }.prefix(caseCount - chosen.count)

        var tapGenerator = SeededRandomGenerator(seed: seed)
        var barGenerator = SeededRandomGenerator(seed: seed ^ 0xBA45)
        return chosen.sorted().map { index in
            let candidate = candidates[index]
            let letterCounts = candidate.tapped.map { $0.filter { $0 != "'" }.count }
            return TypingRegressionCase(
                intended: candidate.intended,
                words: candidate.tapped,
                taps: letterCounts.map { count in
                    (0..<count).map { _ in
                        TypingPlanBuilder.gaussianPair(standardDeviation: noiseInKeyPitches, generator: &tapGenerator)
                            .map { ($0 * offsetSteps).rounded() / offsetSteps }
                    }
                },
                bars: barPoints(letterCounts: letterCounts, generator: &barGenerator)
            )
        }
    }

    /// The sentence's words and the letters tapped for them, or nil when a word holds a character
    /// neither a key nor its plain letter's key types, or the dictionary does not offer it and it
    /// is typed on keys alone or written with a capital.
    private static func candidate(
        for sentence: String,
        layout: KeyboardLayoutModel,
        offered: Set<String>
    ) -> Candidate? {
        let written = SentenceWords.tokens(in: sentence)
        let words = written.map { $0.lowercased() }
        guard wordCounts.contains(words.count) else { return nil }
        var hasPlainTypedLetter = false
        var tapped: [String] = []
        for (word, writing) in zip(words, written) {
            var letters = ""
            for character in word {
                if character == "'" || layout.center(of: character) != nil {
                    letters.append(character)
                } else if let plain = plainLetter(of: character), layout.center(of: plain) != nil {
                    letters.append(plain)
                } else {
                    return nil
                }
            }
            let typedPlain = letters != word
            guard offered.contains(word) || (typedPlain && writing == word) else { return nil }
            hasPlainTypedLetter = hasPlainTypedLetter || typedPlain
            tapped.append(letters)
        }
        return Candidate(
            intended: words,
            tapped: tapped,
            hasPlainTypedLetter: hasPlainTypedLetter,
            hasApostrophe: words.contains { $0.contains("'") }
        )
    }

    /// The letter `character` is written on without its marks, or nil when it has none.
    private static func plainLetter(of character: Character) -> Character? {
        guard let base = String(character).decomposedStringWithCanonicalMapping.unicodeScalars.first,
              base.properties.isAlphabetic else { return nil }
        let plain = Character(base)
        return plain == character ? nil : plain
    }

    /// After the space before a word other than the first, and partway through words of three
    /// letters or more, ordered as they are typed.
    private static func barPoints(
        letterCounts: [Int],
        generator: inout SeededRandomGenerator
    ) -> [SessionTyper.BarPoint] {
        var points = [SessionTyper.BarPoint(word: Int.random(in: 1..<letterCounts.count, using: &generator), letters: 0)]
        let long = letterCounts.indices.filter { letterCounts[$0] >= 3 }.shuffled(using: &generator)
        for word in long.prefix(completionBarCount) {
            points.append(SessionTyper.BarPoint(
                word: word,
                letters: Int.random(in: 1..<letterCounts[word], using: &generator)
            ))
        }
        return points.sorted { ($0.word, $0.letters) < ($1.word, $1.letters) }
    }
}
