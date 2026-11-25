import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Turns a swipe into ranked spellings: a typing language's bundled swipe model reads the path
/// in the frame of the keys on screen, and a beam search walks the language's swipe lexicon and
/// the user's own words with what the model says, each candidate ranked by
/// `SwipeCandidateScoring`.
///
/// The files are the language's own (`PredictiveData/<language>/`): `swipe.json`, the encoder,
/// the swipe lexicon built for that model, and the decoder when the model has one. The decoder
/// reads one fixed key layout, so a model with one is bundled per language; the encoder alone
/// reads any layout from its key centers.
final class SwipeWordDecoder: @unchecked Sendable {
    let settings: SwipeModelSettings
    private let layout: LetterKeyLayout
    private let encoder: SwipeEncoderNetwork
    private let decoder: SwipeDecoderNetwork?
    private let lexicon: SwipeLexicon

    init(language: TypingLanguage) throws {
        let resources = language.resources
        settings = try SwipeModelSettings(contentsOf: resources.url("swipe.json"))
        layout = language.letterLayout
        encoder = try SwipeEncoderNetwork(contentsOf: resources.url(SwipeEncoderNetwork.fileName))
        decoder = try resources.optionalURL(SwipeDecoderNetwork.fileName).map(SwipeDecoderNetwork.init(contentsOf:))
        lexicon = try SwipeLexicon(contentsOf: resources.url(SwipeLexiconFormat.fileName))
        let symbols = settings.letters.unicodeScalars.count + 1
        let frameWidth = symbols + encoder.coefficientCount + 1
        guard lexicon.letters == settings.letters,
              lexicon.keepsDoubleLetters == settings.keepsDoubleLetters,
              decoder.map({ $0.symbols == symbols && $0.inputs == frameWidth }) ?? true else {
            throw PredictiveKeyboardError.invalidSwipeModel("swipe.json")
        }
    }

    /// A lexicon of `words` built for this model, searched beside the bundled one.
    func personalLexicon(_ words: [String]) throws -> SwipeLexicon {
        try SwipeLexicon(data: SwipeLexiconBuilder.fileData(
            words: words.map { SwipeLexiconBuilder.Word(spelling: $0, probability: 0, isOfferable: true) },
            settings: settings
        ))
    }

    /// The model's per-frame log-probabilities for `path` on the keys `keys` lays out, blank
    /// first, or nil when those keys lack one of the model's letters.
    func emissions(for path: [SwipeTouchSample], keys: KeyCenterMap) -> [Float]? {
        guard path.isEmpty == false,
              let frame = SwipeKeyboardFrame(keys: keys, layout: layout, letters: settings.letters) else {
            return nil
        }
        let points = SwipePathResampler.resample(
            path.map { sample in
                let point = frame.normalized(sample.location)
                return (sample.timestamp, point.x, point.y)
            },
            points: encoder.points
        )
        return emissions(forResampled: points, keyCenters: frame.keyCenters)
    }

    /// The per-frame log-probabilities for a path already resampled into the model's frame.
    func emissions(forResampled points: [Float], keyCenters: [(x: Float, y: Float)]) -> [Float] {
        let frames = encoder.frames(path: points, keyCenters: keyCenters)
        if let decoder {
            return decoder.logProbabilities(for: frames)
        }
        let symbols = keyCenters.count + 1
        return (0..<frames.count).flatMap { frame in
            frames.values[frame * frames.width..<frame * frames.width + symbols]
        }
    }

    /// The best spellings for `emissions`, best first, from the bundled lexicon and `personal`.
    ///
    /// Words whose key paths are the same, such as a word and its doubled-letter twin ("to" and
    /// "too", once a repeated letter is one key), look the same to the model, so their scores differ
    /// only by frequency and context; among them, a loop the finger made around a key and, when
    /// there are words before, the context counted `samePathContextWeight` rather than
    /// `contextWeight` decide which takes which of their places (`rankingSamePaths`).
    /// - Parameters:
    ///   - contextLift: How much likelier the words before make a spelling, as a natural log; nil
    ///     ranks without context.
    ///   - hasWordsBefore: Whether any words come before, rather than the sentence starting.
    ///   - loopedKeys: For each key of a key path, whether the swipe looped around it
    ///     (`SwipeKeyLoop`); nil when the swipe's path is not at hand.
    ///   - twinFacts: What the language's data says about a spelling, for weighing twins; nil
    ///     treats every twin as an everyday word.
    func candidates(
        emissions: [Float],
        personal: SwipeLexicon?,
        contextLift: ((String) throws -> Double)?,
        hasWordsBefore: Bool,
        loopedKeys: (([Int]) -> [Bool]?)?,
        twinFacts: ((String) -> SwipeTwinFacts)? = nil
    ) rethrows -> [SwipeCandidate] {
        let scoring = SwipeCandidateScoring(settings: settings.scoring)
        let symbols = settings.letters.unicodeScalars.count + 1
        var forms: [(base: Double, spellings: [(spelling: String, frequency: Double)], isPersonal: Bool)] = []
        for (source, isPersonal) in [(lexicon, false)] + (personal.map { [($0, true)] } ?? []) {
            source.withTables { tables in
                for ending in SwipeBeamSearch.endings(
                    emissions: emissions, symbols: symbols, lexicon: tables, pruning: settings.pruning
                ) {
                    for form in Int(tables.formStart[ending.node])..<Int(tables.formStart[ending.node + 1]) {
                        let frequency = isPersonal
                            ? settings.scoring.personalWordFrequency
                            : Double(tables.formFrequency[form])
                        let base = scoring.formScore(
                            logProbability: Double(ending.logProbability),
                            pathLength: Int(tables.formPathLength[form]),
                            frequency: frequency
                        )
                        let spellings = tables.spellings(of: form).map {
                            ($0.spelling, isPersonal ? frequency : Double($0.probability))
                        }
                        forms.append((base, spellings, isPersonal))
                    }
                }
            }
        }
        forms.sort { $0.base > $1.base }
        var weighed = Array(forms.prefix(settings.scoring.contextCandidates))
        if loopedKeys != nil {
            // Every twin of a weighed word is weighed too, so a loop can pick it.
            let paths = Set(weighed.compactMap { keyPath(of: $0.spellings.first?.spelling) })
            weighed += forms.dropFirst(weighed.count).filter { paths.contains(keyPath(of: $0.spellings.first?.spelling) ?? []) }
        }
        var candidates: [SwipeCandidate] = []
        for form in weighed {
            let formFrequency = form.spellings.map(\.frequency).max() ?? 0
            for spelling in form.spellings {
                let lift = try contextLift?(spelling.spelling) ?? 0
                candidates.append(SwipeCandidate(
                    spelling: spelling.spelling,
                    isPersonal: form.isPersonal,
                    score: scoring.spellingScore(
                        formScore: form.base,
                        formFrequency: formFrequency,
                        spellingFrequency: spelling.frequency,
                        contextLift: lift
                    ),
                    contextLift: lift
                ))
            }
        }
        let usesContext = contextLift != nil && hasWordsBefore
        if usesContext || loopedKeys != nil {
            rankingSamePaths(&candidates, usesContext: usesContext, loopedKeys: loopedKeys, twinFacts: twinFacts)
        }
        return candidates.sorted { $0.score > $1.score }
    }

    /// For each key of `keyPath`, on the keys `keys` lays out, whether `path` loops around it; nil
    /// when the model has no loop settings or the keys lack one of its letters.
    func loopedKeys(path: [SwipeTouchSample], keyPath: [Int], keys: KeyCenterMap) -> [Bool]? {
        guard let loops = settings.loops, settings.keepsDoubleLetters == false else { return nil }
        let letters = Array(settings.letters.unicodeScalars)
        var centers: [CGPoint] = []
        for key in keyPath {
            guard let center = keys.center(of: Character(letters[key])) else { return nil }
            centers.append(center)
        }
        return SwipeKeyLoop.loopedKeys(path: path, centers: centers, pitch: Double(keys.pitch.width), settings: loops)
    }

    private func keyPath(of spelling: String?) -> [Int]? {
        spelling.flatMap {
            SwipeLetterForm.keyPath(
                of: SwipeLetterForm.form(of: $0),
                keyIndex: settings.keyIndex,
                keepsDoubleLetters: settings.keepsDoubleLetters
            )
        }
    }

    /// Reorders the words of each set sharing a key path: the first takes the best of the set's
    /// words' best scores, the next the next best, and so on, each word's spellings moving with it.
    /// The scores the set holds stay the same, so every ranking outside it stays as scored, and so
    /// does the order of a word's own spellings, such as its case and apostrophe variants.
    ///
    /// Between twins, words whose letters differ only in how many times letters repeat at their
    /// keys, the circles decide, whatever the words before or their frequencies, key by key. A loop
    /// around a key where a word has the letter exactly twice credits the word, whether or not a
    /// twin has it once; a word with it three times or more gets nothing from the loop, as a loop
    /// asks for the letter doubled, not tripled. Where a word repeats a letter with no loop credit,
    /// its twins repeating it fewer times and no letter more, and the same at every key a loop
    /// credits the word, win unless every one is a misspelling of it, written `misspellingRatio`
    /// times less often in the context model, the rule the language data's swipe vocabulary build
    /// leaves misspellings out by; then it wins over them, except a twin a loop credits at that key.
    /// So circling either "ss" of "possess" gives "possess". A word a loop credits also loses to
    /// any word on its path that doubles a letter where no loop was read and lacks a credited
    /// double, when that word is written `misspellingRatio` times as often, as a loop read where the
    /// finger only turned on its way is likelier than the rare word it would ask for: "dropped" with
    /// a loop read at its "o" stays "dropped", not "drooped", and "rom" circled at its "m" gives
    /// "room".
    /// Names and the user's own words are weighed the same way. A word losing to a twin at any key
    /// comes after the words that lose at fewer, whatever its loops, so a loop never brings in
    /// letters added at other keys; among the rest, the word with more loop credits comes first.
    /// So "been" beats "Ben", "hello" beats "helo", and "see" beats "se", while "Mary" beats
    /// "marry", "Paris" beats "Parris", and a contact's "Mann" never beats "man", and "yes" circled
    /// at its "e" stays "yes" rather than "yeesss". Words without a twin are untouched. Among words
    /// alike in both, its score with the context counted `samePathContextWeight` times when
    /// `usesContext` ranks it, then its spelling.
    private func rankingSamePaths(
        _ candidates: inout [SwipeCandidate],
        usesContext: Bool,
        loopedKeys: (([Int]) -> [Bool]?)?,
        twinFacts: ((String) -> SwipeTwinFacts)?
    ) {
        var facts: [String: SwipeTwinFacts] = [:]
        func factsOf(_ spelling: String) -> SwipeTwinFacts {
            if let known = facts[spelling] { return known }
            let found = twinFacts?(spelling) ?? SwipeTwinFacts(logFrequency: 0)
            facts[spelling] = found
            return found
        }
        let extraWeight = usesContext ? settings.scoring.samePathContextWeight - settings.scoring.contextWeight : 0
        let keyIndex = settings.keyIndex
        let words = Dictionary(grouping: candidates.indices) { SwipeLetterForm.form(of: candidates[$0].spelling) }
        let sets = Dictionary(grouping: words.keys) { word in
            SwipeLetterForm.keyPath(of: word, keyIndex: keyIndex, keepsDoubleLetters: settings.keepsDoubleLetters) ?? []
        }
        for (path, set) in sets where set.count > 1 && path.isEmpty == false {
            let looped = settings.keepsDoubleLetters ? nil : loopedKeys?(path)
            let repeats = Dictionary(uniqueKeysWithValues: set.compactMap { word in Self.repeats(of: word, keyIndex: keyIndex).map { (word, $0) } })
            func logFrequency(_ word: String) -> Double { words[word]!.map { factsOf(candidates[$0].spelling).logFrequency }.max()! }
            // A twin repeating letters fewer times is a misspelling of the word only when the word is
            // written `misspellingRatio` times as often.
            func isMisspelling(_ shorter: String, of longer: String) -> Bool {
                logFrequency(longer) - logFrequency(shorter) >= log(settings.scoring.misspellingRatio)
            }
            var loops: [String: Int] = [:]
            var unlooped: [String: Int] = [:]
            // A loop asks for a key's letter doubled, not tripled: the keys whose loop credits each word.
            let credited = repeats.mapValues { own -> Set<Int> in
                guard let flags = looped, flags.count == own.count else { return [] }
                return Set(own.indices.filter { flags[$0] && own[$0] == 1 })
            }
            for (longer, own) in repeats {
                let circled = credited[longer]!
                loops[longer] = circled.count
                for key in own.indices where own[key] > 0 && circled.contains(key) == false {
                    // Its twins at this key: words repeating this key's letter fewer times and no letter
                    // more, the same at every key a loop credits it, so a circled letter never counts
                    // against it.
                    let shorter = repeats.filter { other in
                        other.value.count == own.count && other.value[key] < own[key]
                            && other.value.indices.allSatisfy { other.value[$0] <= own[$0] }
                            && circled.allSatisfy { other.value[$0] == own[$0] }
                    }.map(\.key)
                    guard shorter.isEmpty == false else { continue }
                    if shorter.contains(where: { isMisspelling($0, of: longer) == false }) {
                        unlooped[longer, default: 0] += 1
                    } else {
                        // A twin a loop credits at this key is what the loop asked for.
                        for word in shorter where credited[word]!.contains(key) == false {
                            unlooped[word, default: 0] += 1
                        }
                    }
                }
            }
            // A word a loop credits loses to a word on its path that doubles a letter where no loop was
            // read and lacks a credited double, when that word is written `misspellingRatio` times as
            // often: a loop read where the finger merely turned does not make "dropped" "drooped".
            for (word, circles) in credited where circles.isEmpty == false {
                let own = repeats[word]!
                let flags = looped ?? own.map { _ in false }
                let commoner = repeats.contains { other, runs in
                    other != word && runs.count == own.count
                        && runs.indices.contains { runs[$0] > own[$0] && flags[$0] == false }
                        && circles.contains { runs[$0] < own[$0] }
                        && logFrequency(other) - logFrequency(word) >= log(settings.scoring.misspellingRatio)
                }
                if commoner { unlooped[word, default: 0] += 1 }
            }
            let entries = set.map { word -> (word: String, best: SwipeCandidate, loops: Int, unlooped: Int, rank: Double) in
                let best = words[word]!.map { candidates[$0] }.max { $0.score < $1.score }!
                return (word, best, loops[word] ?? 0, unlooped[word] ?? 0, best.score + extraWeight * best.contextLift)
            }
            let places = entries.map(\.best.score).sorted(by: >)
            let order = entries.sorted {
                if $0.unlooped != $1.unlooped { return $0.unlooped < $1.unlooped }
                if $0.loops != $1.loops { return $0.loops > $1.loops }
                if $0.rank != $1.rank { return $0.rank > $1.rank }
                return $0.best.score != $1.best.score ? $0.best.score > $1.best.score : $0.word < $1.word
            }
            var previous = Double.infinity
            for (entry, sortedPlace) in zip(order, places) {
                // Equal scores would leave the order to the final sort; each place is below the last.
                let place = min(sortedPlace, previous.nextDown)
                previous = place
                let shift = place - entry.best.score
                for index in words[entry.word]! {
                    let candidate = candidates[index]
                    candidates[index] = SwipeCandidate(
                        spelling: candidate.spelling,
                        isPersonal: candidate.isPersonal,
                        score: candidate.score + shift,
                        contextLift: candidate.contextLift
                    )
                }
            }
        }
    }

    /// For each key of `form`'s key path with repeats counted once, how many more times its letter
    /// follows itself there; nil when one of its letters has no key.
    private static func repeats(of form: String, keyIndex: [Unicode.Scalar: Int]) -> [Int]? {
        var last: Int?
        var repeats: [Int] = []
        for scalar in form.unicodeScalars {
            guard let key = keyIndex[scalar] else { return nil }
            if key == last { repeats[repeats.count - 1] += 1 } else { repeats.append(0) }
            last = key
        }
        return repeats
    }
}
