import Foundation

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
    /// "too", once a repeated letter is one key), look the same to the swipe, so their scores
    /// differ only by frequency and context; when there are words before, the context counts
    /// `samePathContextWeight` rather than `contextWeight` among them in deciding which takes which
    /// of their places (`rankingSamePathsByContext`).
    /// - Parameters:
    ///   - contextLift: How much likelier the words before make a spelling, as a natural log; nil
    ///     ranks without context.
    ///   - hasWordsBefore: Whether any words come before, rather than the sentence starting.
    func candidates(
        emissions: [Float],
        personal: SwipeLexicon?,
        contextLift: ((String) throws -> Double)?,
        hasWordsBefore: Bool
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
        var candidates: [SwipeCandidate] = []
        for form in forms.prefix(settings.scoring.contextCandidates) {
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
        if contextLift != nil, hasWordsBefore {
            rankingSamePathsByContext(&candidates)
        }
        return candidates.sorted { $0.score > $1.score }
    }

    /// Reorders the words of each set sharing a key path by their scores with the context counted
    /// `samePathContextWeight` times: the first takes the best of the set's words' best scores, the
    /// next the next best, and so on, each word's spellings moving with it. The scores the set holds
    /// stay the same, so every ranking outside it stays as scored, and so does the order of a word's
    /// own spellings, such as its case and apostrophe variants.
    private func rankingSamePathsByContext(_ candidates: inout [SwipeCandidate]) {
        let extraWeight = settings.scoring.samePathContextWeight - settings.scoring.contextWeight
        let words = Dictionary(grouping: candidates.indices) { SwipeLetterForm.form(of: candidates[$0].spelling) }
        let sets = Dictionary(grouping: words.keys) { word in
            SwipeLetterForm.keyPath(
                of: word,
                keyIndex: settings.keyIndex,
                keepsDoubleLetters: settings.keepsDoubleLetters
            ) ?? []
        }
        for set in sets.values where set.count > 1 {
            let bests = set.map { word -> (word: String, best: SwipeCandidate) in
                let best = words[word]!.map { candidates[$0] }.max { $0.score < $1.score }!
                return (word, best)
            }
            let places = bests.map(\.best.score).sorted(by: >)
            let order = bests.sorted {
                let left = $0.best.score + extraWeight * $0.best.contextLift
                let right = $1.best.score + extraWeight * $1.best.contextLift
                return left != right ? left > right : $0.best.score > $1.best.score
            }
            for (entry, place) in zip(order, places) {
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
}
