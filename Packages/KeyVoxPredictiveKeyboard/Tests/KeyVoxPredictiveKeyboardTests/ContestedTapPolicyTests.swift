import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Which taps on delete inside a word may be meant for the letter key beside it.
final class ContestedTapPolicyTests: XCTestCase {
    private let policy = ContestedTapPolicy()

    func testTouchOnDeleteInsideWordKeepsDelete() {
        XCTAssertNil(policy.intendedLetter(for: deleteTap(landedOnDelete: true)))
    }

    func testTouchInGapBesideDeleteInsideWordGoesToNearbyLetter() {
        let tap = deleteTap(landedOnDelete: false)
        XCTAssertEqual(policy.intendedLetter(for: tap), tap.letters.first?.letter)
    }

    /// A tap inside a word with one nearby letter that leads to a real word, close enough for
    /// delete to yield to it.
    private func deleteTap(landedOnDelete: Bool) -> ContestedTap {
        let distance = policy.maximumDistance(for: .delete) / 2
        let letter = EnglishKeyboardLayout.defaultGeometry[0].character
        return ContestedTap(
            otherKey: .delete,
            landedOnOtherKey: landedOnDelete,
            startsWord: false,
            letters: [ContestedTap.Letter(letter: letter, distance: distance, continuationLogProbability: 0)],
            endingLogProbability: nil
        )
    }
}
