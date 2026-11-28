import Foundation
import KeyVoxPredictiveKeyboard
import KeyVoxTypingSimulation

/// Builds a typing language's regression cases (`regression-cases`): sentences of the corpus
/// whose every word its keys type and the language's dictionary offers, or, for a word holding a
/// letter no key types, which a language may keep beside its dictionary, that the sentence writes
/// in lowercase, so never a name. A quarter of them have a word holding a letter no key types,
/// typed with the accent key where the key shows its mark, or as its plain letter for
/// autocorrection to restore, and a quarter an apostrophe, where the corpus has enough; the rest
/// are any, swapped, where the corpus has them, until a quarter hold a letter with marks on a key
/// of its own and a quarter open with a sentence opening mark of the language, shared evenly
/// between its marks. Every
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
        let hasMarkedLetterKey: Bool
        /// The sentence opening mark typed before the first word, if any.
        let openingMark: Character?
    }

    /// What decides how a sentence's characters are tapped.
    private struct Typist {
        let language: TypingLanguage
        let layout: KeyboardLayoutModel
        let computer: PredictionComputer
        let offered: Set<String>
    }

    static func build(
        languageIdentifier: String,
        corpusPaths: [String],
        caseCount: Int,
        noiseInKeyPitches: Double,
        seed: UInt64
    ) throws -> [TypingRegressionCase] {
        let language = try TypingLanguage.bundled(identifier: languageIdentifier)
        let engine = try PredictiveEngine(language: language)
        let typist = Typist(
            language: language,
            layout: KeyboardLayoutModel(language: language),
            computer: PredictionComputer(engine: engine),
            offered: Set(try engine.dictionaryWords().filter(\.isOfferable).map { $0.spelling.lowercased() })
        )

        var shuffleGenerator = SeededRandomGenerator(seed: seed ^ 0x5EED)
        let candidates = try CorpusLoader.sentences(from: corpusPaths)
            .compactMap { candidate(for: $0, typist: typist) }
            .shuffled(using: &shuffleGenerator)

        let quota = caseCount / 4
        var chosen: [Int] = []
        for wanted in [\Candidate.hasPlainTypedLetter, \Candidate.hasApostrophe] {
            chosen += candidates.indices
                .filter { candidates[$0][keyPath: wanted] && chosen.contains($0) == false }
                .prefix(quota)
        }
        let filled = chosen.count
        chosen += candidates.indices.filter { chosen.contains($0) == false }.prefix(caseCount - chosen.count)
        let marks = language.textRules.sentenceOpeningMarks.sorted()
        let swapped: [(wanted: (Candidate) -> Bool, quota: Int)] = [({ $0.hasMarkedLetterKey }, quota)]
            + marks.map { mark in ({ $0.openingMark == mark }, quota / marks.count) }
        for (wanted, quota) in swapped {
            let missing = quota - chosen.filter { wanted(candidates[$0]) }.count
            guard missing > 0 else { continue }
            let added = candidates.indices
                .filter { wanted(candidates[$0]) && chosen.contains($0) == false }
                .prefix(missing)
            let replaced = chosen[filled...]
                .filter { index in swapped.allSatisfy { $0.wanted(candidates[index]) == false } }
                .suffix(added.count)
            chosen = chosen.filter { replaced.contains($0) == false } + added.prefix(replaced.count)
        }

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

    /// The sentence's words and the characters tapped for them, or nil when a word holds a
    /// character that neither a key, the accent key, its plain letter's key, nor a key's held
    /// popup types, or the dictionary does not offer it and it is typed without a plain letter or
    /// written with a capital. A letter no key types is typed with the accent key when the key
    /// shows its mark after the letters before it, otherwise as its plain letter, or, with neither
    /// a key nor a plain letter on one, picked from the popup offering it. An apostrophe is typed
    /// on the accent key where the key shows the apostrophe, and otherwise left for autocorrection
    /// to restore. A sentence opening mark before the first word is typed with it.
    private static func candidate(for sentence: String, typist: Typist) -> Candidate? {
        let written = SentenceWords.tokens(in: sentence)
        let words = written.map { $0.lowercased() }
        guard wordCounts.contains(words.count) else { return nil }
        let layout = typist.layout
        var hasPlainTypedLetter = false
        var hasMarkedLetterKey = false
        var tapped: [String] = []
        for (index, (word, writing)) in zip(words, written).enumerated() {
            let before = words[..<index].map { $0 + " " }.joined()
            var letters = ""
            var typedMarkedLetter = false
            for (offset, character) in word.enumerated() {
                let prefix = before + word.prefix(offset)
                if character == "'" {
                    letters.append(accentKeyTypes(character, after: prefix, typist: typist) ? accentKeyCharacter(typist) : character)
                } else if layout.keyFrames[character] != nil {
                    letters.append(character)
                    hasMarkedLetterKey = hasMarkedLetterKey || plainLetter(of: character) != nil
                } else if let plain = plainLetter(of: character), layout.keyFrames[plain] != nil {
                    letters.append(plain)
                    if accentKeyTypes(character, after: prefix + String(plain), typist: typist) {
                        letters.append(accentKeyCharacter(typist))
                    }
                    typedMarkedLetter = true
                } else if layout.types(character) {
                    letters.append(character)
                } else {
                    return nil
                }
            }
            guard typist.offered.contains(word) || (typedMarkedLetter && writing == word) else { return nil }
            hasPlainTypedLetter = hasPlainTypedLetter || typedMarkedLetter
            tapped.append(letters)
        }
        var intended = words
        let openingMark = sentence.trimmingCharacters(in: .whitespaces).first
            .flatMap { typist.language.textRules.sentenceOpeningMarks.contains($0) ? $0 : nil }
        if let mark = openingMark {
            intended[0] = String(mark) + intended[0]
            tapped[0] = String(mark) + tapped[0]
        }
        return Candidate(
            intended: intended,
            tapped: tapped,
            hasPlainTypedLetter: hasPlainTypedLetter,
            hasApostrophe: words.contains { $0.contains("'") },
            hasMarkedLetterKey: hasMarkedLetterKey,
            openingMark: openingMark
        )
    }

    /// Whether the language's accent key, tapped after `text`, leaves `character`: the apostrophe
    /// it types, or the marked letter it makes of the letter before it.
    private static func accentKeyTypes(_ character: Character, after text: String, typist: Typist) -> Bool {
        guard let accentKey = typist.language.accentKey,
              let mark = typist.computer.accentKeyMark(after: text) else { return false }
        if let edit = accentKey.edit(placing: mark, after: text) {
            return edit.insertText == String(character)
        }
        let typed = typist.language.quotes.text(for: mark, after: text)
        return typist.language.textRules.straightApostrophes(in: typed) == String(character)
    }

    private static func accentKeyCharacter(_ typist: Typist) -> Character {
        typist.language.accentKey!.character.first!
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
