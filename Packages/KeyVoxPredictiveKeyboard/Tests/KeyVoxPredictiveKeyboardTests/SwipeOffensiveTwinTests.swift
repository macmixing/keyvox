import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Which slur-class words of the swipe lexicon a doubled-letter gesture could make of a twin with
/// fewer repeated letters on the same keys, and what does: swiped plain, the twin never gives the
/// slur; drawn with a loop or a squiggle at each key the slur repeats more, each outcome is listed
/// with what decided it: the gesture's credit, the rule that a word written `misspellingRatio` times
/// as often wins over a gestured one, or the rule that a gesture never triples a letter.
///
/// Slur-class words are those a profanity list tags as racial or anti-LGBTQ at any severity, or as
/// religious at strong severity or above, which leaves out religious exclamations. The list is not
/// bundled: the test runs only with `SWIPE_OFFENSIVE_WORDS` naming a JSON file in the format
/// of github.com/dsojevic/profanity-list's `en.json`, in any build
/// (`SWIPE_OFFENSIVE_WORDS=<en.json> swift test --filter SwipeOffensiveTwinTests`).
final class SwipeOffensiveTwinTests: XCTestCase {
    private struct Entry: Decodable {
        /// Terms separated by "|"; a letter followed by "*" appears one or more times.
        let match: String
        let tags: [String]?
        /// 1 mild, 2 medium, 3 strong, 4 severe.
        let severity: Int

        var isSlurClass: Bool {
            let tags = Set(self.tags ?? [])
            return tags.isDisjoint(with: ["racial", "lgbtq"]) == false || (tags.contains("religious") && severity >= 3)
        }
    }

    private enum Gesture: CaseIterable { case loop, squiggle }

    private var engine: PredictiveEngine!
    private var decoder: SwipeWordDecoder!
    private let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)

    func testNoPlainSwipeGivesASlurAndEveryGesturedTwinIsListed() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let listPath = environment["SWIPE_OFFENSIVE_WORDS"] else { throw XCTSkip("set SWIPE_OFFENSIVE_WORDS to run") }
        let entries = try JSONDecoder().decode([Entry].self, from: Data(contentsOf: URL(fileURLWithPath: listPath)))
        let terms: [String] = entries.filter(\.isSlurClass)
            .flatMap { $0.match.split(separator: "|") }
            .map(String.init)
            .filter { $0.contains(" ") == false }
        let patterns: [NSRegularExpression] = try terms.map { term in
            let escaped: String = NSRegularExpression.escapedPattern(for: term).replacingOccurrences(of: "\\*", with: "+")
            return try NSRegularExpression(pattern: "^\(escaped)$")
        }
        engine = try PredictiveEngine(language: .english)
        decoder = try SwipeWordDecoder(language: .english)
        let keyIndex = decoder.settings.keyIndex

        var spellings: [String: [String]] = [:]
        var groups: [[Int]: [String: [Int]]] = [:]
        for word in try SwipeVocabulary.lexiconWords(of: engine) {
            let form = SwipeLetterForm.form(of: word.spelling)
            guard let runs = Self.runs(of: form), let path = SwipeLetterForm.keyPath(of: form, keyIndex: keyIndex, keepsDoubleLetters: false) else { continue }
            spellings[form, default: []].append(word.spelling)
            groups[path, default: [:]][form] = runs
        }
        func isSlur(_ form: String) -> Bool {
            patterns.contains { $0.firstMatch(in: form, range: NSRange(form.startIndex..., in: form)) != nil }
        }
        func logFrequency(_ form: String) -> Double {
            spellings[form]!.map { SwipeTwinFacts(spelling: $0, engine: engine).logFrequency }.max()!
        }

        var pairs = 0, plainSlurs: [String] = [], gesturedSlurs = 0, byRatio = 0, byTriple = 0
        for (path, forms) in groups.sorted(by: { $0.key.lexicographicallyPrecedes($1.key) }) {
            for (slur, slurRuns) in forms.sorted(by: { $0.key < $1.key }) where isSlur(slur) {
                for (twin, twinRuns) in forms.sorted(by: { $0.key < $1.key }) where isSlur(twin) == false
                    && twinRuns.indices.allSatisfy({ twinRuns[$0] <= slurRuns[$0] }) && twinRuns != slurRuns {
                    pairs += 1
                    let added = Set(slurRuns.indices.filter { slurRuns[$0] > twinRuns[$0] })
                    let letters = Self.letters(of: path, settings: decoder.settings)
                    let plain = try decode(letters, gesture: .loop, at: [])
                    if plain == slur { plainSlurs.append(twin) }
                    var outcomes: [String] = []
                    for gesture in Gesture.allCases {
                        if added.contains(where: { slurRuns[$0] > 2 }) {
                            byTriple += 1
                            outcomes.append("\(gesture): no gesture triples a letter")
                            continue
                        }
                        let top = try decode(letters, gesture: gesture, at: added)
                        let swipe = self.swipe(letters, gesture: gesture, at: added)
                        let read = decoder.doublingKeys(path: swipe, keyPath: path, keys: keys).map { flags in Set(flags.indices.filter { flags[$0] }) }
                        if top == slur {
                            gesturedSlurs += 1
                        } else if read == added, logFrequency(top ?? twin) - logFrequency(slur) >= log(decoder.settings.scoring.misspellingRatio) {
                            byRatio += 1
                        }
                        outcomes.append("\(gesture) read \(read.map { $0.sorted() } ?? []) gives \(top ?? "-")")
                    }
                    print(String(
                        format: "OFFENSIVE_TWIN %@ (log frequency %.1f) -> %@ (%.1f) at keys %@: plain gives %@; %@",
                        twin, logFrequency(twin), slur, logFrequency(slur), "\(added.sorted())", plain ?? "-", outcomes.joined(separator: "; ")
                    ))
                }
            }
        }
        print("OFFENSIVE_TWIN pairs \(pairs): plain gives the slur \(plainSlurs.count), a gesture drawn at the added letters gives it \(gesturedSlurs), the misspelling ratio keeps a commoner word \(byRatio), the triple rule keeps it out \(byTriple)")
        XCTAssertGreaterThan(pairs, 0, "the list reaches the lexicon")
        XCTAssertEqual(plainSlurs, [], "a plain swipe gave a slur-class word")
    }

    /// A swipe through `letters` making `gesture` at the keys `at`.
    private func swipe(_ letters: String, gesture: Gesture, at keys: Set<Int>) -> [SwipeTouchSample] {
        gesture == .loop ? SwipePath.through(letters, loopingAt: keys) : SwipePath.through(letters, squigglingAt: keys)
    }

    /// The letter form of the best spelling for a swipe through `letters`, making `gesture` at the
    /// keys `at`, at a sentence start, with the keyboard's scoring and its doubling gestures.
    private func decode(_ letters: String, gesture: Gesture, at keys: Set<Int>) throws -> String? {
        let path = swipe(letters, gesture: gesture, at: keys)
        guard let emissions = decoder.emissions(for: path, keys: self.keys) else { return nil }
        let language = ContextLanguageScorer(engine: engine, vocabulary: PersonalVocabulary(words: [], textReplacements: []))
        let candidates = try decoder.candidates(
            emissions: emissions,
            personal: nil,
            contextLift: { try language.contextLift(of: $0, previousWords: []) },
            hasWordsBefore: false,
            doublingKeys: { [decoder, keys = self.keys] keyPath in decoder!.doublingKeys(path: path, keyPath: keyPath, keys: keys) },
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
