import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class DictionaryMatcherTests: XCTestCase {
    func testExactPhraseIsPreserved() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "Dom Esposito")
        XCTAssertTrue(result.text == "Dom Esposito")
    }

    func testPhoneticMissIsCorrectedForCustomName() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "Dom Espicito")
        XCTAssertTrue(result.text == "Dom Esposito")
    }

    func testCommonWordGuardPreventsAggressiveReplacement() {
        let lexicon = FakeLexicon(
            pronunciations: [
                "cueboard": "KBRD",
                "keyboard": "KBRD",
            ],
            commonWords: ["keyboard"]
        )
        let matcher = DictionaryMatcher(lexicon: lexicon, encoder: PhoneticEncoder(), scorer: .balanced)
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "keyboard shortcuts")
        XCTAssertTrue(result.text == "keyboard shortcuts")
    }

    func testOverlapResolutionKeepsBestNonOverlappingReplacement() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "MiGo Platform"),
            DictionaryEntry(phrase: "Platform"),
        ])

        let result = matcher.apply(to: "migo platform is live")
        XCTAssertTrue(result.text == "MiGo Platform is live")
    }

    func testSplitTwoTokensJoinToSingleBrand() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "open cue board now")
        XCTAssertTrue(result.text == "open Cueboard now")
    }

    func testPluralSecondTokenCanJoinForBrand() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "this is cue boards")
        XCTAssertTrue(result.text == "this is Cueboard")
    }

    func testSplitJoinDoesNotInferPossessive() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "this is a test of cue boards abilities")
        XCTAssertTrue(result.text == "this is a test of Cueboard abilities")
    }

    func testPossessiveSingleTokenKeepsSuffixWhileCorrectingWord() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "show CuBoard's abilities")
        XCTAssertTrue(result.text == "show Cueboard's abilities")
    }

    func testSplitJoinPossessiveKeepsSuffixWhileCorrectingWord() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "show cue board's abilities")
        XCTAssertTrue(result.text == "show Cueboard's abilities")
    }

    func testDoesNotOvercorrectCommonPhrase() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "we use cue cards often")
        XCTAssertTrue(result.text == "we use cue cards often")
    }

    private func makeMatcher() -> DictionaryMatcher {
        let lexicon = FakeLexicon(pronunciations: [
            "dom": "DM",
            "espicito": "ESPST",
            "esposito": "ESPST",
            "migo": "MGO",
            "platform": "PLTRM",
            "cueboard": "KBRD",
            "keyboard": "KBRD",
        ])

        return DictionaryMatcher(lexicon: lexicon, encoder: PhoneticEncoder(), scorer: .balanced)
    }
}
