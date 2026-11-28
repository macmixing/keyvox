import XCTest
@testable import KeyVoxPredictiveKeyboard

/// Which taps on delete or the accent key may be meant for the letter key beside them.
final class ContestedTapPolicyTests: XCTestCase {
    private let policy = ContestedTapPolicy()

    func testTouchOnDeleteInsideWordKeepsDelete() {
        XCTAssertNil(policy.intendedLetter(for: deleteTap(landedOnDelete: true)))
    }

    func testTouchInGapBesideDeleteInsideWordGoesToNearbyLetter() {
        let tap = deleteTap(landedOnDelete: false)
        XCTAssertEqual(policy.intendedLetter(for: tap), tap.letters.first?.letter)
    }

    func testTouchOnTheAccentKeyGoesToTheLetterWhenWhatTheKeyLeavesBeginsNoWord() {
        XCTAssertNotNil(policy.intendedLetter(for: accentKeyTap(startsWord: false, ending: nil)))
        XCTAssertNotNil(policy.intendedLetter(for: accentKeyTap(startsWord: true, ending: nil)))
    }

    func testTouchOnTheAccentKeyKeepsItWhenTheWordItLeavesIsLikelier() {
        XCTAssertNil(policy.intendedLetter(for: accentKeyTap(startsWord: false, ending: 10)))
    }

    /// A tap on the accent key with one nearby letter that leads to a real word.
    private func accentKeyTap(startsWord: Bool, ending: Double?) -> ContestedTap {
        let letter = TypingLanguage.french.letterLayout.defaultGeometry[0].character
        return ContestedTap(
            otherKey: .accentKey,
            landedOnOtherKey: true,
            startsWord: startsWord,
            letters: [ContestedTap.Letter(letter: letter, distance: policy.maximumDistance(for: .accentKey) / 2, continuationLogProbability: 0)],
            endingLogProbability: ending
        )
    }

    /// A tap inside a word with one nearby letter that leads to a real word, close enough for
    /// delete to yield to it.
    private func deleteTap(landedOnDelete: Bool) -> ContestedTap {
        let distance = policy.maximumDistance(for: .delete) / 2
        let letter = TypingLanguage.english.letterLayout.defaultGeometry[0].character
        return ContestedTap(
            otherKey: .delete,
            landedOnOtherKey: landedOnDelete,
            startsWord: false,
            letters: [ContestedTap.Letter(letter: letter, distance: distance, continuationLogProbability: 0)],
            endingLogProbability: nil
        )
    }
}
