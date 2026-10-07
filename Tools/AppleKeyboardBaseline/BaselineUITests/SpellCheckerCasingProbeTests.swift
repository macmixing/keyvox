import UIKit
import XCTest

/// Measurement only: asks the system spell checker, for each word in
/// `TEST_RUNNER_CASING_WORDS` (a JSON array), whether its lowercase form is an ordinary
/// word, and what it would write instead. Writes `[{"word", "lowercaseIsWord", "guesses"}]`
/// to `TEST_RUNNER_CASING_OUTPUT`.
final class SpellCheckerCasingProbeTests: XCTestCase {
    private struct Result: Encodable {
        let word: String
        let lowercaseIsWord: Bool
        let guesses: [String]
    }

    func testProbeCasing() throws {
        let environment = ProcessInfo.processInfo.environment
        let wordsPath = try XCTUnwrap(environment["CASING_WORDS"])
        let outputPath = try XCTUnwrap(environment["CASING_OUTPUT"])
        let words = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: wordsPath)))
        let checker = UITextChecker()
        let results = words.map { word -> Result in
            let lower = word.lowercased()
            let range = NSRange(location: 0, length: (lower as NSString).length)
            let misspelled = checker.rangeOfMisspelledWord(
                in: lower, range: range, startingAt: 0, wrap: false, language: "en_US"
            )
            let guesses = misspelled.location == NSNotFound
                ? []
                : checker.guesses(forWordRange: misspelled, in: lower, language: "en_US") ?? []
            return Result(word: word, lowercaseIsWord: misspelled.location == NSNotFound, guesses: Array(guesses.prefix(4)))
        }
        try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }
}
