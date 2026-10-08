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

    /// A tap on `key` of the default layout, moved from its center by fractions of its size.
    private func touch(on key: Character, offsetBy offset: CGVector) -> CGPoint {
        let frame = EnglishKeyboardLayout.defaultGeometry.first { $0.character == key }!.frame
        return CGPoint(x: frame.midX + offset.dx * frame.width, y: frame.midY + offset.dy * frame.height)
    }
}
