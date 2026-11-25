import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Every doubled-letter twin decodes as the circle asks: twins are words on one key path whose
/// letters differ by one doubled run, found from the bundled swipe lexicon itself, plus a user's
/// word doubling a letter of a dictionary word. Swiped without a loop, the single word comes out,
/// unless the language data says it is not a word people mean against a twin (a name, a word typing
/// does not take, or a misspelling of the twin, `SwipeTwinFacts`) that is no name, when one of those
/// twins does; swiped with a
/// loop at the doubled key, the doubled word does. The same swipes decoded with loop
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
    /// The twins each single word is not meant against, from every twin checked so far.
    private var beatenBy: [String: Set<String>] = [:]
    private var engine: PredictiveEngine!
    private let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)

    func testEveryTwinFollowsTheCircle() throws {
        let environment = ProcessInfo.processInfo.environment
        try XCTSkipUnless(environment["SWIPE_TWIN_PROOF"] == "1", "set SWIPE_TWIN_PROOF=1 to run")
        engine = try PredictiveEngine(language: .english)
        decoder = try SwipeWordDecoder(language: .english)
        let keyIndex = decoder.settings.keyIndex

        var groups: [[Int]: [String: [Int]]] = [:]
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
                    guard differing.count == 1, let key = differing.first else { continue }
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

    private struct Results {
        var plainSingle = 0, plainDoubled = 0, loopedDoubled = 0, otherWord = 0
        var withoutDetection = (plainSingle: 0, loopedDoubled: 0)
        var wrongTwin: [String] = []
        var detectorMissed: [String] = []
        var summary: String {
            "no loop -> single \(plainSingle), no loop -> doubled as the single is not meant \(plainDoubled), loop -> doubled \(loopedDoubled), an unrelated word \(otherWord), against the circle \(wrongTwin.count), swipes whose loops the detector read wrong \(detectorMissed.count); "
                + "with loop detection off: no loop -> single \(withoutDetection.plainSingle), loop -> doubled \(withoutDetection.loopedDoubled)"
        }
    }

    /// Each twin's swipe without a loop must decode to a word on its key path doubling no letter,
    /// or, when the single word is not meant against some of its twins that are no names, to one of
    /// those; with a loop at the doubled key, to one doubling that key's letter alone.
    private func check(_ twins: [Twin], personal: SwipeLexicon?, vocabulary: PersonalVocabulary) throws -> Results {
        var results = Results()
        let ratio = log(decoder.settings.scoring.misspellingRatio)
        func facts(_ form: String, personal: Bool) -> [SwipeTwinFacts] {
            (personal ? [form] : spellings[form] ?? [form]).map { SwipeTwinFacts(spelling: $0, engine: engine) }
        }
        func isNamed(_ form: String, personal: Bool) -> Bool { personal || facts(form, personal: false).allSatisfy(\.isNameOnly) }
        func logFrequency(_ form: String, personal: Bool) -> Double { facts(form, personal: personal).map(\.logFrequency).max()! }
        for twin in twins {
            let singleIsMeant = isNamed(twin.single, personal: false) == false
                && facts(twin.single, personal: false).contains(where: \.isValid)
                && logFrequency(twin.doubled, personal: personal != nil) - logFrequency(twin.single, personal: false) < ratio
            if singleIsMeant == false, isNamed(twin.doubled, personal: personal != nil) == false {
                beatenBy[twin.single, default: []].insert(twin.doubled)
            }
        }
        for twin in twins {
            let path = SwipeLetterForm.keyPath(of: twin.single, keyIndex: decoder.settings.keyIndex, keepsDoubleLetters: false)
            let winners = beatenBy[twin.single] ?? []
            // Without a loop, a single beaten by twins must give one of them, whichever keys it doubles.
            let plain: Set<Int> = winners.isEmpty ? [] : [-1]
            for (loops, expected) in [(Set<Int>(), plain), (Set([twin.key]), Set([twin.key]))] {
                let top = try decode(twin.letters, loopingAt: loops, personal: personal, vocabulary: vocabulary, detectsLoops: true)
                let doubles = loops.isEmpty && winners.contains(top ?? "") ? Self.doubledKeys(top, on: path) ?? expected : expected
                let swipe = SwipePath.through(twin.letters, loopingAt: loops)
                let detected = decoder.loopedKeys(path: swipe, keyPath: path ?? [], keys: keys).map { flags in Set(flags.indices.filter { flags[$0] }) }
                let undetected = try decode(twin.letters, loopingAt: loops, personal: personal, vocabulary: vocabulary, detectsLoops: false)
                if detected != loops { results.detectorMissed.append("\(twin.letters) drawn \(loops.sorted()) detected \(detected.map { $0.sorted() } ?? [])") }
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

    /// The keys of `path` whose letter `form` doubles, or nil when `form` is not on `path`.
    private static func doubledKeys(_ form: String?, on path: [Int]?) -> Set<Int>? {
        guard let form, let path, let runs = runs(of: form),
              SwipeLetterForm.keyPath(of: form, keyIndex: SwipeModelSettings.englishKeyIndex, keepsDoubleLetters: false) == path else { return nil }
        return Set(runs.indices.filter { runs[$0] > 1 })
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
