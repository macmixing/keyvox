import CoreGraphics
import XCTest
@testable import KeyVoxPredictiveKeyboard

/// A finished word whose taps all landed on its own keys is not rewritten once the next
/// word is typed, even when the next word reads better after another word.
final class WordRevisionTests: XCTestCase {
    private var computer: PredictionComputer!

    override func setUpWithError() throws {
        computer = PredictionComputer(engine: try EnglishPredictiveEngine())
    }

    /// "lol" typed with ordinary finger spread on l, o, l, then "what": not "look what".
    func testWordTypedOnItsOwnKeysIsKeptBeforeNextWord() throws {
        let touches = [
            touch(on: "l", offsetBy: CGVector(dx: 0.12, dy: -0.19)),
            touch(on: "o", offsetBy: CGVector(dx: -0.07, dy: -0.09)),
            touch(on: "l", offsetBy: CGVector(dx: -0.27, dy: -0.30)),
        ]
        for typed in ["lol", "Lol"] {
            let revision = try computer.revision(for: RevisionRequest(
                word: typed,
                touches: touches,
                previousWords: [],
                followingWord: "what"
            ))
            XCTAssertNil(revision, "\(typed) became \(revision ?? "")")
        }
    }

    /// A finished word one slip away from a better word is fixed once the next word shows it:
    /// "I male mistakes" and "I night be".
    func testWordOneSlipAwayIsFixedByTheNextWord() throws {
        for (typed, following, expected) in [("male", "mistakes", "make"), ("night", "be", "might")] {
            let revision = try computer.revision(for: RevisionRequest(
                word: typed,
                touches: typed.map { touch(on: $0, offsetBy: .zero) },
                previousWords: ["i"],
                followingWord: following
            ))
            XCTAssertEqual(revision, expected, "\(typed) before \(following)")
        }
    }

    /// A finished word typed on its keys' centers that a likelier word is a slip away from is
    /// kept unless the next word shows the likelier one, as the system keyboard keeps "or ant
    /// like", "I do hot know", "bow are you", and "I fan do it" but makes "we ate going" "we are
    /// going".
    func testNextWordReplacesAWordOnlyWhereItShowsTheReplacement() throws {
        let cases: [(previous: [String], typed: String, following: String, expected: String?)] = [
            (["or", "swarm", "with"], "ant", "like", nil),
            (["do", "i"], "hot", "know", nil),
            ([], "bow", "are", nil),
            (["i"], "fan", "do", nil),
            (["we"], "ate", "going", "are"),
        ]
        for (previous, typed, following, expected) in cases {
            let revision = try computer.revision(for: RevisionRequest(
                word: typed,
                touches: typed.map { touch(on: $0, offsetBy: .zero) },
                previousWords: previous,
                followingWord: following
            ))
            XCTAssertEqual(revision, expected, "\(typed) before \(following)")
        }
    }

    /// "never kind that" keeps "kind" typed on its keys and becomes "never mind that" once "k"
    /// was tapped toward "m", as on the system keyboard.
    func testNextWordReplacesAWordWhoseTapsLandedTowardTheReplacement() throws {
        for (offset, expected) in [(0.0, nil), (0.3, "mind")] as [(CGFloat, String?)] {
            let touches = [touch(on: "k", offsetBy: CGVector(dx: 0, dy: offset))]
                + "ind".map { touch(on: $0, offsetBy: .zero) }
            let revision = try computer.revision(for: RevisionRequest(
                word: "kind",
                touches: touches,
                previousWords: ["never"],
                followingWord: "that"
            ))
            XCTAssertEqual(revision, expected, "k tapped \(offset) toward m")
        }
    }

    /// A tap on `key` of the default layout, moved from its center by fractions of its size.
    private func touch(on key: Character, offsetBy offset: CGVector) -> CGPoint {
        let frame = EnglishKeyboardLayout.defaultGeometry.first { $0.character == key }!.frame
        return CGPoint(x: frame.midX + offset.dx * frame.width, y: frame.midY + offset.dy * frame.height)
    }
}
