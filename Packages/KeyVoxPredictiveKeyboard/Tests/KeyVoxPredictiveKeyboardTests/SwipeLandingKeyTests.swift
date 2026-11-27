import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import KeyVoxPredictiveKeyboard

/// A swipe drawn from one key's center to another's gives a word on those two keys, even when a
/// likelier word starts on the key beside the first: the pairs are found from the bundled swipe
/// lexicon itself. The landing says nothing when the swipe is loose about either end or lands
/// between the two first keys (`SwipeLandingKey`).
final class SwipeLandingKeyTests: XCTestCase {
    private let keys = KeyCenterMap(geometry: TypingLanguage.english.letterLayout.defaultGeometry)

    func testASwipeBetweenTwoKeysGivesAWordOnThemOverALikelierWordAKeyOver() throws {
        let engine = try PredictiveEngine(language: .english)
        let computer = PredictionComputer(engine: engine)
        let settings = try SwipeModelSettings.bundled(for: .english)
        let keyIndex = settings.keyIndex
        func keyPath(of spelling: String) -> [Int]? {
            SwipeLetterForm.keyPath(of: SwipeLetterForm.form(of: spelling), keyIndex: keyIndex, keepsDoubleLetters: settings.keepsDoubleLetters)
        }
        // Each two-key path's likeliest dictionary word and its probability.
        var likeliest: [[Int]: (word: String, probability: Int)] = [:]
        for word in try engine.dictionaryWords() where word.isOfferable {
            guard let path = keyPath(of: word.spelling), path.count == 2 else { continue }
            if word.probability > (likeliest[path]?.probability ?? -1) {
                likeliest[path] = (SwipeLetterForm.form(of: word.spelling), word.probability)
            }
        }
        let letters = Array(settings.letters)
        var swiped = 0
        var lost: [String] = []
        for (path, entry) in likeliest {
            guard let first = keys.center(of: letters[path[0]]) else { continue }
            // The likelier words on a key beside the first key and the same second key.
            let beside = likeliest.filter { other, otherEntry in
                guard other[1] == path[1], other[0] != path[0], otherEntry.probability > entry.probability,
                      let center = keys.center(of: letters[other[0]]) else { return false }
                return center.y == first.y && abs(Double(center.x - first.x)) <= Double(keys.pitch.width) * 1.01
            }.map(\.key)
            guard beside.isEmpty == false else { continue }
            swiped += 1
            let paths = try computer.swipeCandidates(for: SwipePath.through(entry.word), previousWords: [])
                .map { keyPath(of: $0.spelling) }
            let own = paths.firstIndex(of: path) ?? Int.max
            for other in beside where (paths.firstIndex(of: other) ?? Int.max) < own {
                lost.append("\(entry.word): \(likeliest[other]!.word) \(likeliest[other]!.probability - entry.probability)")
            }
        }
        XCTAssertGreaterThan(swiped, 0)
        XCTAssertEqual(lost.sorted(), [], "a likelier word starting a key over outranked the word on the swiped keys")
    }

    /// The landing trades places only among words with the same keys after the first: ranked with
    /// and without it, the scores are the same, and each place holds the same word or one that
    /// differs from it only in its first key.
    func testTheLandingMovesNoWordAgainstWordsOnOtherKeys() throws {
        let decoder = try SwipeWordDecoder(language: .english)
        let keyIndex = decoder.settings.keyIndex
        func keyPath(of spelling: String) -> [Int] {
            SwipeLetterForm.keyPath(
                of: SwipeLetterForm.form(of: spelling), keyIndex: keyIndex, keepsDoubleLetters: decoder.settings.keepsDoubleLetters
            ) ?? []
        }
        let (_, row) = try topRow()
        var moved = 0
        for (from, to) in zip(row, row.dropFirst(3)) {
            let path = [0.0, 0.05, 0.1, 0.15, 0.2].map { time in
                SwipeTouchSample(
                    location: CGPoint(
                        x: from.center.x + (to.center.x - from.center.x) * time / 0.2,
                        y: from.center.y + (to.center.y - from.center.y) * time / 0.2
                    ),
                    timestamp: time
                )
            }
            let emissions = try XCTUnwrap(decoder.emissions(for: path, keys: keys))
            let losses = try XCTUnwrap(decoder.landingLosses(path: path, keys: keys))
            func ranked(_ landingLosses: [Double]?) -> [SwipeCandidate] {
                decoder.candidates(
                    emissions: emissions, personal: nil, contextLift: nil, hasWordsBefore: false,
                    doublingKeys: nil, landingLosses: landingLosses
                )
            }
            // Each word's best spelling, in rank order.
            func words(_ candidates: [SwipeCandidate]) -> [(path: [Int], score: Double)] {
                var seen: Set<String> = []
                return candidates.compactMap { candidate in
                    seen.insert(SwipeLetterForm.form(of: candidate.spelling)).inserted
                        ? (keyPath(of: candidate.spelling), candidate.score) : nil
                }
            }
            let plain = words(ranked(nil))
            let landed = words(ranked(losses))
            XCTAssertEqual(plain.map(\.score), landed.prefix(plain.count).map(\.score))
            for (before, after) in zip(plain, landed) where before.path != after.path {
                XCTAssertEqual(before.path.dropFirst(), after.path.dropFirst(), "a word moved against a word on other keys")
                moved += 1
            }
        }
        XCTAssertGreaterThan(moved, 0, "no swipe's landing reordered anything")
    }

    func testALandingAtAKeysCenterCostsOnlyWordsStartingOnOtherKeys() throws {
        let (settings, row) = try topRow()
        let losses = try XCTUnwrap(losses(from: row[1].center, to: row[4].center, settings: settings))
        XCTAssertLessThan(losses[row[1].key], 0.05 * settings.weight)
        XCTAssertGreaterThan(losses[row[0].key], 0.9 * settings.weight)
        XCTAssertGreaterThan(losses[row[2].key], 0.9 * settings.weight)
    }

    func testALandingTowardTheKeyBesideLeavesTheTwoKeysWordsToTheirScores() throws {
        let (settings, row) = try topRow()
        let toward = CGPoint(x: row[1].center.x + 0.3 * (row[2].center.x - row[1].center.x), y: row[1].center.y)
        let losses = try XCTUnwrap(losses(from: toward, to: row[4].center, settings: settings))
        XCTAssertLessThan(abs(losses[row[2].key] - losses[row[1].key]), 0.05 * settings.weight)
        XCTAssertGreaterThan(losses[row[0].key], 0.5 * settings.weight, "the key on the other side is left behind")
    }

    func testASwipeLooseAboutWhereItLiftsOrLandsCostsNothing() throws {
        let (settings, row) = try topRow()
        let between = CGPoint(x: (row[4].center.x + row[5].center.x) / 2, y: row[4].center.y + keys.pitch.height / 2)
        for (from, to) in [(row[1].center, between), (between, row[1].center)] {
            let losses = try XCTUnwrap(losses(from: from, to: to, settings: settings))
            XCTAssertLessThan(losses.max() ?? .infinity, 0.05 * settings.weight)
        }
    }

    /// The bundled landing settings and the top letter row's keys, left to right, each with its
    /// index among the model's keys.
    private func topRow() throws -> (SwipeLandingKey.Settings, [(key: Int, center: CGPoint)]) {
        let settings = try SwipeModelSettings.bundled(for: .english)
        let centers = settings.letters.enumerated().compactMap { index, letter in
            keys.center(of: letter).map { (key: index, center: $0) }
        }
        let top = try XCTUnwrap(centers.map(\.center.y).min())
        return (try XCTUnwrap(settings.landing), centers.filter { $0.center.y == top }.sorted { $0.center.x < $1.center.x })
    }

    private func losses(from landing: CGPoint, to lift: CGPoint, settings: SwipeLandingKey.Settings) throws -> [Double]? {
        SwipeLandingKey.losses(
            path: [SwipeTouchSample(location: landing, timestamp: 0), SwipeTouchSample(location: lift, timestamp: 0.2)],
            keys: keys,
            letters: try SwipeModelSettings.bundled(for: .english).letters,
            settings: settings
        )
    }
}
