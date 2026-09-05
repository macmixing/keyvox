import Foundation
import XCTest
@testable import KeyVoxCore

@MainActor
final class DictionaryMatcherCoreLogicTests: XCTestCase {
    func testStylizedFallbackRequiresActualInternalUppercase() {
        let matcher = makeMatcher()
        let punctuationOnly = DictionaryMatcher.Token(
            raw: "Α'α",
            normalized: "α'α",
            range: NSRange(location: 0, length: 3),
            phonetic: ""
        )
        let actualInternalUppercase = DictionaryMatcher.Token(
            raw: "Α'Β",
            normalized: "α'β",
            range: NSRange(location: 0, length: 3),
            phonetic: ""
        )

        XCTAssertFalse(
            matcher.allowStylizedFallbackForCommonObservedToken(
                token: punctuationOnly,
                tokenIndex: 0,
                totalTokens: 2
            )
        )
        XCTAssertTrue(
            matcher.allowStylizedFallbackForCommonObservedToken(
                token: actualInternalUppercase,
                tokenIndex: 0,
                totalTokens: 2
            )
        )
    }

    func testOverlapResolverPrefersHigherScoreThenLongerSpanThenEarlierStart() {
        let matcher = makeMatcher()

        let proposed: [DictionaryMatcher.ProposedReplacement] = [
            .init(tokenStart: 1, tokenEndExclusive: 2, range: NSRange(location: 5, length: 3), replacement: "A", score: 0.91),
            .init(tokenStart: 1, tokenEndExclusive: 3, range: NSRange(location: 5, length: 7), replacement: "B", score: 0.91),
            .init(tokenStart: 0, tokenEndExclusive: 2, range: NSRange(location: 0, length: 7), replacement: "C", score: 0.91),
            .init(tokenStart: 4, tokenEndExclusive: 5, range: NSRange(location: 20, length: 3), replacement: "D", score: 0.90),
        ]

        var rejected = 0
        let selected = matcher.selectNonOverlapping(proposed: proposed, rejectedOverlapCounter: &rejected)

        XCTAssertTrue(selected.contains(where: { $0.replacement == "C" }))
        XCTAssertTrue(!selected.contains(where: { $0.replacement == "B" }))
        XCTAssertTrue(!selected.contains(where: { $0.replacement == "A" }))
        XCTAssertTrue(selected.contains(where: { $0.replacement == "D" }))
        XCTAssertTrue(rejected == 2)
    }

    func testSplitJoinFormsIncludeDirectPluralAndPossessiveVariants() {
        let matcher = makeMatcher()

        let pluralWindow: [DictionaryMatcher.Token] = [
            .init(raw: "cue", normalized: "cue", range: NSRange(location: 0, length: 3), phonetic: "K"),
            .init(raw: "boards", normalized: "boards", range: NSRange(location: 4, length: 6), phonetic: "BRDZ"),
        ]

        let pluralForms = matcher.splitJoinForms(from: pluralWindow)
        XCTAssertTrue(pluralForms.contains(where: { $0.normalized == "cueboards" && !$0.singularizedSecondToken && $0.replacementSuffix.isEmpty }))
        XCTAssertTrue(pluralForms.contains(where: { $0.normalized == "cueboard" && $0.singularizedSecondToken && $0.replacementSuffix == "s" }))

        let possessiveWindow: [DictionaryMatcher.Token] = [
            .init(raw: "cue", normalized: "cue", range: NSRange(location: 0, length: 3), phonetic: "K"),
            .init(raw: "board's", normalized: "board's", range: NSRange(location: 4, length: 7), phonetic: "BRDZ"),
        ]

        let possessiveForms = matcher.splitJoinForms(from: possessiveWindow)
        XCTAssertTrue(possessiveForms.contains(where: { $0.normalized == "cueboard" && !$0.singularizedSecondToken && $0.replacementSuffix == "'s" }))
    }

    func testSingleTokenPossessiveObservedFormsIncludeStemVariant() {
        let matcher = makeMatcher()

        let window: [DictionaryMatcher.Token] = [
            .init(raw: "cueboard's", normalized: "cueboard's", range: NSRange(location: 0, length: 10), phonetic: "KBRDZ"),
        ]
        let forms = matcher.observedFormsForWindow(
            tokenCount: 1,
            window: window,
            observedNormalized: "cueboard's",
            observedPhonetic: "KBRDZ"
        )

        XCTAssertTrue(forms.contains(where: { $0.normalized == "cueboard's" && $0.replacementSuffix.isEmpty }))
        XCTAssertTrue(forms.contains(where: { $0.normalized == "cueboard" && $0.replacementSuffix == "'s" }))
    }

    func testStandardCandidateSelectionRanksOnlyPhoneticallyEligibleCandidates() throws {
        let observed = "abcdefghij"
        let ineligibleCandidate = "abcdefzhij"
        let eligibleCandidate = "abcdzzzzij"
        let matcher = DictionaryMatcher(
            lexicon: FakeLexicon(pronunciations: [
                observed: "BKTFR",
                ineligibleCandidate: "BKNSR",
                eligibleCandidate: "BKTFS",
            ]),
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: ineligibleCandidate),
            DictionaryEntry(phrase: eligibleCandidate),
        ])

        let tokens = matcher.tokenize(observed)
        let token = try XCTUnwrap(tokens.first)
        let candidates = try XCTUnwrap(matcher.entriesByTokenCount[1])
        let selection = matcher.selectBestStandardCandidate(
            start: 0,
            tokenCount: 1,
            tokens: tokens,
            candidates: candidates,
            window: [token],
            observedNormalized: token.normalized,
            observedPhonetic: token.phonetic
        )

        XCTAssertEqual(selection?.candidate.entry.normalizedPhrase, eligibleCandidate)
    }

    func testTextNormalizationMatchesExistingBehavior() {
        XCTAssertTrue(DictionaryTextNormalization.normalizedPhrase("  Cue—Board!!! ") == "cue board")
        XCTAssertTrue(DictionaryTextNormalization.normalizedPhrase("Crème Brûlée") == "creme brulee")
        XCTAssertTrue(DictionaryTextNormalization.normalizedToken("Cue Board") == "cueboard")
        XCTAssertTrue(DictionaryTextNormalization.normalizedToken("  ") == "")
    }

    private func makeMatcher() -> DictionaryMatcher {
        let lexicon = FakeLexicon(pronunciations: [
            "cue": "K",
            "board": "BRD",
            "boards": "BRDZ",
            "cueboard": "KBRD",
        ])

        return DictionaryMatcher(lexicon: lexicon, encoder: PhoneticEncoder(), scorer: .balanced)
    }
}
