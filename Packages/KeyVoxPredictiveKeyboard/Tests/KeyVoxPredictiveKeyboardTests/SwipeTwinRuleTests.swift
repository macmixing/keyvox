import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Every doubled-letter twin decodes as the circle asks: twins are words on one key path whose
/// letters differ by one letter doubled, found from the bundled swipe lexicon itself, plus a user's
/// word doubling a letter of a dictionary word. Swiped without a loop, the single word comes out,
/// unless it is a misspelling of a twin, written `misspellingRatio` times less often in the context
/// model (`SwipeTwinFacts`), when one of those twins does, names and the user's words alike; swiped
/// with a loop at the doubled key, the doubled word does. The same swipes decoded with loop
/// detection off show what the circle does without it, and doubled-letter words without a single
/// twin are listed as they decode.
///
/// It decodes thousands of swipes, so it runs only with `SWIPE_TWIN_PROOF=1`, in a release build
/// (`swift test -c release -Xswiftc -enable-testing --filter SwipeTwinRuleTests`).
/// `SWIPE_TWIN_PROOF_OUTPUT`, when set, receives the doubled-letter words without a twin that
/// decode to themselves, one a line, to compare builds.
final class SwipeTwinRuleTests: XCTestCase {
    private struct Twin {
        let letters: String
        let single: String
        let doubled: String
        let key: Int
    }

    private var decoder: SwipeWordDecoder!
    /// Every spelling the lexicon has for each letter form.
    private var spellings: [String: [String]] = [:]
    /// The twins each single word misspells, from every twin checked so far.
    private var beatenBy: [String: Set<String>] = [:]
    /// The lexicon's letter forms on each key path.
    private var groups: [[Int]: [String: [Int]]] = [:]
    private var engine: PredictiveEngine!
    private let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)

    func testEveryTwinFollowsTheCircle() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["SWIPE_TWIN_PROOF"] == "1", "set SWIPE_TWIN_PROOF=1 to run")
        engine = try PredictiveEngine(language: .english)
        decoder = try SwipeWordDecoder(language: .english)
        let keyIndex = decoder.settings.keyIndex

        var frequency: [String: Int] = [:]
        let lexiconWords = try SwipeVocabulary.lexiconWords(of: engine)
        for word in lexiconWords { spellings[SwipeLetterForm.form(of: word.spelling), default: []].append(word.spelling) }
        for word in lexiconWords where word.isOfferable {
            let form = SwipeLetterForm.form(of: word.spelling)
            guard form.count > 1, let path = SwipeLetterForm.keyPath(of: form, keyIndex: keyIndex, keepsDoubleLetters: false),
                  let runs = Self.runs(of: form) else { continue }
            groups[path, default: [:]][form] = runs
            frequency[form] = max(frequency[form] ?? 0, word.probability)
        }

        var twins: [Twin] = []
        for (path, forms) in groups where forms.count > 1 {
            for (single, singleRuns) in forms where singleRuns.allSatisfy({ $0 == 1 }) {
                for (doubled, doubledRuns) in forms {
                    let differing = singleRuns.indices.filter { singleRuns[$0] != doubledRuns[$0] }
                    guard differing.count == 1, let key = differing.first, doubledRuns[key] == 2 else { continue }
                    twins.append(Twin(letters: Self.letters(of: path, settings: decoder.settings), single: single, doubled: doubled, key: key))
                }
            }
        }
        let dictionary = try check(twins, personal: nil, vocabulary: PersonalVocabulary(words: [], textReplacements: []))
        print("TWIN_PROOF dictionary twins \(twins.count): \(dictionary.summary)")
        for line in dictionary.wrongTwin.prefix(20) { print("TWIN_FAIL \(line)") }
        for line in dictionary.detectorMissed.prefix(20) { print("TWIN_DETECTOR \(line)") }

        // A user's word, a contact, doubling the last letter of each of 300 common dictionary words.
        let common = groups.values.flatMap { $0 }.filter { $0.key.count >= 3 && $0.key.count <= 8 && $0.value.allSatisfy { $0 == 1 } }
            .map(\.key).sorted { (frequency[$0] ?? 0, $1) > (frequency[$1] ?? 0, $0) }
        var personalTwins: [Twin] = []
        for form in common where personalTwins.count < 300 {
            let doubled = form + String(form.last!)
            let path = SwipeLetterForm.keyPath(of: form, keyIndex: keyIndex, keepsDoubleLetters: false) ?? []
            guard groups[path]?[doubled] == nil else { continue }
            personalTwins.append(Twin(letters: form, single: form, doubled: doubled, key: path.count - 1))
        }
        let names = personalTwins.map { $0.doubled.prefix(1).uppercased() + $0.doubled.dropFirst() }
        let personal = try check(
            personalTwins,
            personal: decoder.personalLexicon(names),
            vocabulary: PersonalVocabulary(words: [], knownNames: names, textReplacements: [])
        )
        print("TWIN_PROOF contact twins \(personalTwins.count): \(personal.summary)")
        // A twin decodes against the circle only where the detector read its loops wrong.
        let againstTheCircle = (dictionary.wrongTwin + personal.wrongTwin).filter { line in
            (dictionary.detectorMissed + personal.detectorMissed).contains { $0.hasPrefix(line.split(separator: " ")[1].dropLast() + " ") } == false
        }
        XCTAssertEqual(againstTheCircle, [], "a twin decoded against the circle with its loops read right")

        let lone = groups.flatMap { _, forms -> [String] in
            forms.compactMap { form, runs in
                guard runs.contains(where: { $0 > 1 }) else { return nil }
                let hasSingleTwin = forms.contains { other, otherRuns in
                    zip(runs, otherRuns).filter { $0 != $1 }.count == 1 && zip(runs, otherRuns).contains { $0 != $1 && min($0, $1) == 1 }
                }
                return hasSingleTwin ? nil : form
            }
        }.sorted()
        var decodedToItself: [String] = []
        for form in lone {
            let path = SwipeLetterForm.keyPath(of: form, keyIndex: keyIndex, keepsDoubleLetters: false) ?? []
            let top = try decode(Self.letters(of: path, settings: decoder.settings), loopingAt: [], personal: nil, vocabulary: PersonalVocabulary(words: [], textReplacements: []), detectsLoops: true)
            if top == form { decodedToItself.append(form) }
        }
        print("TWIN_PROOF doubled-letter words without a single twin \(lone.count), decoded to themselves unlooped \(decodedToItself.count)")
        if let output = environment["SWIPE_TWIN_PROOF_OUTPUT"] {
            try decodedToItself.joined(separator: "\n").write(toFile: output, atomically: true, encoding: .utf8)
        }
    }

    /// Every lexicon word with two or three doubled letters, each exactly twice, swiped circling only
    /// some of them: whatever twin of the word wins keeps every circled letter doubled, and drops an
    /// uncircled double only for a word that is not the word's misspelling, as no circle adds a
    /// letter but none drops one for a misspelling. So circling either "ss" of "possess" gives
    /// "possess", never "posses" or "poses". A word doubling another letter, written 50 times as
    /// often as the circled word, wins over it instead.
    func testCirclingSomeDoubledLettersOfAWordWeighsTheOthersByTheirOwnTwins() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SWIPE_TWIN_PROOF"] == "1", "set SWIPE_TWIN_PROOF=1 to run")
        engine = try PredictiveEngine(language: .english)
        decoder = try SwipeWordDecoder(language: .english)
        let keyIndex = decoder.settings.keyIndex
        var spellingsOf: [String: [String]] = [:]
        for word in try SwipeVocabulary.lexiconWords(of: engine) {
            spellingsOf[SwipeLetterForm.form(of: word.spelling), default: []].append(word.spelling)
        }
        func logFrequency(_ form: String) -> Double {
            spellingsOf[form]!.map { SwipeTwinFacts(spelling: $0, engine: engine).logFrequency }.max()!
        }
        let ratio = log(decoder.settings.scoring.misspellingRatio)
        var cases = 0, weighed = 0, misread = 0, anotherPath = 0, toACommonerWord = 0
        var wrong: [String] = []
        for word in spellingsOf.keys.sorted() {
            guard let runs = Self.runs(of: word), runs.allSatisfy({ $0 <= 2 }),
                  let path = SwipeLetterForm.keyPath(of: word, keyIndex: keyIndex, keepsDoubleLetters: false) else { continue }
            let doubles = runs.indices.filter { runs[$0] == 2 }
            guard (2...3).contains(doubles.count) else { continue }
            let letters = Array(Self.letters(of: path, settings: decoder.settings))
            for mask in 1..<((1 << doubles.count) - 1) {
                let circled = Set(doubles.indices.filter { mask & (1 << $0) != 0 }.map { doubles[$0] })
                cases += 1
                let swipe = SwipePath.through(String(letters), loopingAt: circled)
                guard let emissions = decoder.emissions(for: swipe, keys: keys) else { continue }
                let language = ContextLanguageScorer(engine: engine, vocabulary: PersonalVocabulary(words: [], textReplacements: []))
                let candidates = try decoder.candidates(
                    emissions: emissions,
                    personal: nil,
                    contextLift: { try language.contextLift(of: $0, previousWords: []) },
                    hasWordsBefore: false,
                    loopedKeys: { [decoder, keys] keyPath in decoder!.loopedKeys(path: swipe, keyPath: keyPath, keys: keys) },
                    twinFacts: { [engine] spelling in SwipeTwinFacts(spelling: spelling, engine: engine!) }
                )
                guard candidates.contains(where: { SwipeLetterForm.form(of: $0.spelling) == word }) else { continue }
                let detected = decoder.loopedKeys(path: swipe, keyPath: path, keys: keys).map { flags in Set(flags.indices.filter { flags[$0] }) }
                guard detected == circled else { misread += 1; continue }
                weighed += 1
                let forms = candidates.map { SwipeLetterForm.form(of: $0.spelling) }
                let top = forms.first ?? ""
                // A word keeping the circled doubles loses to a word doubling another letter written 50
                // times as often, as the circles' own twins may in turn.
                let beaten = Set(forms.filter { form in
                    guard SwipeLetterForm.keyPath(of: form, keyIndex: keyIndex, keepsDoubleLetters: false) == path,
                          let formRuns = Self.runs(of: form), circled.allSatisfy({ formRuns[$0] == 2 }) else { return false }
                    return commonerWords(than: form, circled: circled, among: forms, logFrequency: logFrequency).isEmpty == false
                })
                if beaten.isEmpty == false {
                    toACommonerWord += 1
                    if beaten.contains(top) { wrong.append("\(word) circled \(circled.sorted()): \(top) kept over a commoner word") }
                    continue
                }
                guard SwipeLetterForm.keyPath(of: top, keyIndex: keyIndex, keepsDoubleLetters: false) == path,
                      let topRuns = Self.runs(of: top) else { anotherPath += 1; continue }
                // A word on the path that is no twin of this one, repeating some letter more, is ranked by its score.
                guard topRuns.indices.allSatisfy({ topRuns[$0] <= runs[$0] }) else { continue }
                let keepsCircles = circled.allSatisfy { topRuns[$0] == 2 }
                let dropsForAMisspelling = top != word && logFrequency(word) - logFrequency(top) >= ratio
                if keepsCircles == false || dropsForAMisspelling { wrong.append("\(word) circled \(circled.sorted()): \(top)") }
            }
        }
        print("TWIN_PROOF circling some doubled letters: cases \(cases), weighed with their circles read \(weighed), circles misread \(misread), lost to a word doubling another letter written 50 times as often \(toACommonerWord), a word on another key path \(anotherPath), a circle lost or a double dropped for a misspelling \(wrong.count)")
        XCTAssertGreaterThan(weighed, 0)
        XCTAssertEqual(wrong, [], "a circled double lost, or an uncircled one dropped for a misspelling")
    }

    /// Every dictionary word with two or more doubled letters, each exactly twice, swiped circling
    /// every one, decodes as itself whenever the decoder weighs it: a circle credits each letter it
    /// finds exactly doubled, so no word loses a doubled letter its circle asked for, except to a
    /// word doubling another letter written 50 times as often, which it must then lose to.
    func testCirclingEveryDoubledLetterOfAWordGivesTheWord() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SWIPE_TWIN_PROOF"] == "1", "set SWIPE_TWIN_PROOF=1 to run")
        engine = try PredictiveEngine(language: .english)
        decoder = try SwipeWordDecoder(language: .english)
        let keyIndex = decoder.settings.keyIndex
        let words = Set(try engine.dictionaryWords().filter(\.isOfferable).map { SwipeLetterForm.form(of: $0.spelling) }).filter { word in
            guard let runs = Self.runs(of: word) else { return false }
            return runs.allSatisfy { $0 <= 2 } && runs.filter { $0 == 2 }.count >= 2
        }
        var weighed = 0, misread = 0, anotherPath = 0, toACommonerWord = 0
        var wrong: [String] = []
        func logFrequency(_ form: String) -> Double {
            (spellings[form] ?? [form]).map { SwipeTwinFacts(spelling: $0, engine: engine).logFrequency }.max()!
        }
        if spellings.isEmpty {
            for word in try SwipeVocabulary.lexiconWords(of: engine) { spellings[SwipeLetterForm.form(of: word.spelling), default: []].append(word.spelling) }
        }
        for word in words.sorted() {
            guard let runs = Self.runs(of: word), let path = SwipeLetterForm.keyPath(of: word, keyIndex: keyIndex, keepsDoubleLetters: false) else { continue }
            let loops = Set(runs.indices.filter { runs[$0] == 2 })
            let letters = Self.letters(of: path, settings: decoder.settings)
            let swipe = SwipePath.through(letters, loopingAt: loops)
            guard let emissions = decoder.emissions(for: swipe, keys: keys) else { continue }
            let language = ContextLanguageScorer(engine: engine, vocabulary: PersonalVocabulary(words: [], textReplacements: []))
            let candidates = try decoder.candidates(
                emissions: emissions,
                personal: nil,
                contextLift: { try language.contextLift(of: $0, previousWords: []) },
                hasWordsBefore: false,
                loopedKeys: { [decoder, keys] keyPath in decoder!.loopedKeys(path: swipe, keyPath: keyPath, keys: keys) },
                twinFacts: { [engine] spelling in SwipeTwinFacts(spelling: spelling, engine: engine!) }
            )
            // The circles only order the words the search found.
            guard candidates.contains(where: { SwipeLetterForm.form(of: $0.spelling) == word }) else { continue }
            let detected = decoder.loopedKeys(path: swipe, keyPath: path, keys: keys).map { flags in Set(flags.indices.filter { flags[$0] }) }
            guard detected == loops else { misread += 1; continue }
            weighed += 1
            let forms = candidates.map { SwipeLetterForm.form(of: $0.spelling) }
            let top = forms.first ?? ""
            // A word doubling another letter written 50 times as often wins over the circled word.
            if commonerWords(than: word, circled: loops, among: forms, logFrequency: logFrequency).isEmpty == false {
                toACommonerWord += 1
                if top == word { wrong.append("\(word): kept over a commoner word") }
                continue
            }
            // A word on another key path wins on the model's score, which the circles do not order.
            guard SwipeLetterForm.keyPath(of: top, keyIndex: keyIndex, keepsDoubleLetters: false) == path else { anotherPath += 1; continue }
            if top != word { wrong.append("\(word): \(top)") }
        }
        print("TWIN_PROOF circling every doubled letter: words \(words.count), weighed with their circles read \(weighed), circles misread \(misread), lost to a word doubling another letter written 50 times as often \(toACommonerWord), a word on another key path \(anotherPath), not as the rule asks \(wrong.count)")
        XCTAssertEqual(wrong, [], "a word with every doubled letter circled decoded against the rule")
    }

    private struct Results {
        var plainSingle = 0, plainDoubled = 0, loopedDoubled = 0, loopedToACommonerWord = 0, otherWord = 0
        var withoutDetection = (plainSingle: 0, loopedDoubled: 0)
        var wrongTwin: [String] = []
        var detectorMissed: [String] = []
        var summary: String {
            "no loop -> single \(plainSingle), no loop -> doubled as the single misspells it \(plainDoubled), loop -> doubled \(loopedDoubled), loop -> a word doubling another letter written 50 times as often \(loopedToACommonerWord), an unrelated word \(otherWord), against the circle \(wrongTwin.count), swipes whose loops the detector read wrong \(detectorMissed.count); "
                + "with loop detection off: no loop -> single \(withoutDetection.plainSingle), loop -> doubled \(withoutDetection.loopedDoubled)"
        }
    }

    /// Each twin's swipe without a loop must decode to a word on its key path doubling no letter,
    /// or, when the single word misspells some of its twins, to one of those; with a loop at the
    /// doubled key, to one doubling that key's letter alone, unless a word doubling another letter
    /// is written 50 times as often, which the doubled twin must then lose to.
    private func check(_ twins: [Twin], personal: SwipeLexicon?, vocabulary: PersonalVocabulary) throws -> Results {
        var results = Results()
        let ratio = log(decoder.settings.scoring.misspellingRatio)
        func facts(_ form: String, personal: Bool) -> [SwipeTwinFacts] {
            (personal ? [form] : spellings[form] ?? [form]).map { SwipeTwinFacts(spelling: $0, engine: engine) }
        }
        func logFrequency(_ form: String, personal: Bool) -> Double { facts(form, personal: personal).map(\.logFrequency).max()! }
        for twin in twins {
            // Every word on its key path repeats each of its letters at least as many times.
            let path = SwipeLetterForm.keyPath(of: twin.single, keyIndex: decoder.settings.keyIndex, keepsDoubleLetters: false) ?? []
            let lexiconTwins = (groups[path] ?? [:]).keys.filter { $0 != twin.single && $0 != twin.doubled }
            for doubled in lexiconTwins + [twin.doubled] {
                let isPersonal = personal != nil && doubled == twin.doubled
                if logFrequency(doubled, personal: isPersonal) - logFrequency(twin.single, personal: false) >= ratio {
                    beatenBy[twin.single, default: []].insert(doubled)
                }
            }
        }
        for twin in twins {
            let path = SwipeLetterForm.keyPath(of: twin.single, keyIndex: decoder.settings.keyIndex, keepsDoubleLetters: false)
            let winners = beatenBy[twin.single] ?? []
            // Without a loop, a single beaten by twins must give one of them, whichever keys it doubles.
            let plain: Set<Int> = winners.isEmpty ? [] : [-1]
            for (loops, expected) in [(Set<Int>(), plain), (Set([twin.key]), Set([twin.key]))] {
                let weighed = try decodeAll(twin.letters, loopingAt: loops, personal: personal, vocabulary: vocabulary, detectsLoops: true)
                let top = weighed.first
                let doubles = loops.isEmpty && winners.contains(top ?? "") ? Self.doubledKeys(top, on: path) ?? expected : expected
                let swipe = SwipePath.through(twin.letters, loopingAt: loops)
                let detected = decoder.loopedKeys(path: swipe, keyPath: path ?? [], keys: keys).map { flags in Set(flags.indices.filter { flags[$0] }) }
                let undetected = try decode(twin.letters, loopingAt: loops, personal: personal, vocabulary: vocabulary, detectsLoops: false)
                if detected != loops { results.detectorMissed.append("\(twin.letters) drawn \(loops.sorted()) detected \(detected.map { $0.sorted() } ?? [])") }
                // A circled twin loses to a word doubling another letter written 50 times as often.
                let commoner = commonerWords(than: twin.doubled, circled: loops, among: weighed) {
                    logFrequency($0, personal: personal != nil && $0 == twin.doubled)
                }
                if detected == loops, commoner.isEmpty == false, weighed.contains(twin.doubled) {
                    if top == twin.doubled {
                        results.wrongTwin.append("LOOPED \(twin.letters): \(twin.doubled) over \(commoner), detected \(loops.sorted())")
                    } else {
                        results.loopedToACommonerWord += 1
                    }
                    continue
                }
                if Self.doubledKeys(top, on: path) == doubles {
                    if loops.isEmpty == false { results.loopedDoubled += 1 } else if doubles.isEmpty { results.plainSingle += 1 } else { results.plainDoubled += 1 }
                } else if Self.doubledKeys(top, on: path) != nil {
                    results.wrongTwin.append("\(loops.isEmpty ? "PLAIN" : "LOOPED") \(twin.letters): \(top ?? "-"), detected \(detected.map { $0.sorted() } ?? [])")
                } else {
                    results.otherWord += 1
                }
                if Self.doubledKeys(undetected, on: path) == doubles {
                    if loops.isEmpty { results.withoutDetection.plainSingle += 1 } else { results.withoutDetection.loopedDoubled += 1 }
                }
            }
        }
        return results
    }

    /// The words among `weighed`, on `form`'s key path, that `form`, with loops credited at
    /// `circled`, loses to: each repeats a letter where no loop was read more than `form` does, has
    /// a circled letter fewer times, and is written `misspellingRatio` times as often
    /// (`SwipeWordDecoder`), as "dropped" beats "drooped" with a loop read at its "o".
    private func commonerWords(than form: String, circled: Set<Int>, among weighed: [String], logFrequency: (String) -> Double) -> [String] {
        guard circled.isEmpty == false, let runs = Self.runs(of: form) else { return [] }
        let keyIndex = decoder.settings.keyIndex
        let path = SwipeLetterForm.keyPath(of: form, keyIndex: keyIndex, keepsDoubleLetters: false)
        let ratio = log(decoder.settings.scoring.misspellingRatio)
        return Set(weighed).filter { other in
            guard other != form, SwipeLetterForm.keyPath(of: other, keyIndex: keyIndex, keepsDoubleLetters: false) == path,
                  let otherRuns = Self.runs(of: other), otherRuns.count == runs.count else { return false }
            return otherRuns.indices.contains { otherRuns[$0] > runs[$0] && circled.contains($0) == false }
                && circled.contains { otherRuns[$0] < runs[$0] }
                && logFrequency(other) - logFrequency(form) >= ratio
        }.sorted()
    }

    /// The keys of `path` whose letter `form` doubles, or nil when `form` is not on `path`.
    private static func doubledKeys(_ form: String?, on path: [Int]?) -> Set<Int>? {
        guard let form, let path, let runs = runs(of: form),
              SwipeLetterForm.keyPath(of: form, keyIndex: SwipeModelSettings.englishKeyIndex, keepsDoubleLetters: false) == path else { return nil }
        return Set(runs.indices.filter { runs[$0] > 1 })
    }

    /// The letter forms of the words weighed for a swipe through `letters`, looping at `loops`, at a
    /// sentence start, best first, with the keyboard's scoring and, unless `detectsLoops` is false,
    /// its loops.
    private func decodeAll(
        _ letters: String,
        loopingAt loops: Set<Int>,
        personal: SwipeLexicon?,
        vocabulary: PersonalVocabulary,
        detectsLoops: Bool
    ) throws -> [String] {
        let path = SwipePath.through(letters, loopingAt: loops)
        guard let emissions = decoder.emissions(for: path, keys: keys) else { return [] }
        let language = ContextLanguageScorer(engine: engine, vocabulary: vocabulary)
        let candidates = try decoder.candidates(
            emissions: emissions,
            personal: personal,
            contextLift: { try language.contextLift(of: $0, previousWords: []) },
            hasWordsBefore: false,
            loopedKeys: detectsLoops ? { [decoder, keys] keyPath in decoder!.loopedKeys(path: path, keyPath: keyPath, keys: keys) } : nil,
            twinFacts: { [engine] spelling in SwipeTwinFacts(spelling: spelling, engine: engine!) }
        )
        return candidates.map { SwipeLetterForm.form(of: $0.spelling) }
    }

    /// The letter form of the best spelling for a swipe through `letters`, looping at `loops`, at a
    /// sentence start, with the keyboard's scoring and, unless `detectsLoops` is false, its loops.
    private func decode(
        _ letters: String,
        loopingAt loops: Set<Int>,
        personal: SwipeLexicon?,
        vocabulary: PersonalVocabulary,
        detectsLoops: Bool
    ) throws -> String? {
        let path = SwipePath.through(letters, loopingAt: loops)
        guard let emissions = decoder.emissions(for: path, keys: keys) else { return nil }
        let language = ContextLanguageScorer(engine: engine, vocabulary: vocabulary)
        let candidates = try decoder.candidates(
            emissions: emissions,
            personal: personal,
            contextLift: { try language.contextLift(of: $0, previousWords: []) },
            hasWordsBefore: false,
            loopedKeys: detectsLoops ? { [decoder, keys] keyPath in decoder!.loopedKeys(path: path, keyPath: keyPath, keys: keys) } : nil,
            twinFacts: { [engine] spelling in SwipeTwinFacts(spelling: spelling, engine: engine!) }
        )
        return candidates.first.map { SwipeLetterForm.form(of: $0.spelling) }
    }

    /// For each key of `form`'s key path with repeats counted once, how many times its letter
    /// repeats there; nil for a letter the default layout has no key for.
    private static func runs(of form: String) -> [Int]? {
        var runs: [Int] = []
        var last: Character?
        for letter in form {
            guard letter.isASCII, letter.isLetter else { return nil }
            if letter == last { runs[runs.count - 1] += 1 } else { runs.append(1) }
            last = letter
        }
        return runs
    }

    private static func letters(of path: [Int], settings: SwipeModelSettings) -> String {
        let letters = Array(settings.letters)
        return String(path.map { letters[$0] })
    }
}

private extension SwipeModelSettings {
    static let englishKeyIndex = (try? SwipeModelSettings.bundled(for: .english).keyIndex) ?? [:]
}
