import Foundation
import Testing
@testable import KeyVox

@MainActor
struct DictionaryMatcherCoreLogicTests {
    @Test
    func overlapResolverPrefersHigherScoreThenLongerSpanThenEarlierStart() {
        let matcher = makeMatcher()

        let proposed: [DictionaryMatcher.ProposedReplacement] = [
            .init(tokenStart: 1, tokenEndExclusive: 2, range: NSRange(location: 5, length: 3), replacement: "A", score: 0.91),
            .init(tokenStart: 1, tokenEndExclusive: 3, range: NSRange(location: 5, length: 7), replacement: "B", score: 0.91),
            .init(tokenStart: 0, tokenEndExclusive: 2, range: NSRange(location: 0, length: 7), replacement: "C", score: 0.91),
            .init(tokenStart: 4, tokenEndExclusive: 5, range: NSRange(location: 20, length: 3), replacement: "D", score: 0.90),
        ]

        var rejected = 0
        let selected = matcher.selectNonOverlapping(proposed: proposed, rejectedOverlapCounter: &rejected)

        #expect(selected.contains(where: { $0.replacement == "C" }))
        #expect(!selected.contains(where: { $0.replacement == "B" }))
        #expect(!selected.contains(where: { $0.replacement == "A" }))
        #expect(selected.contains(where: { $0.replacement == "D" }))
        #expect(rejected == 2)
    }

    @Test
    func splitJoinFormsIncludeDirectPluralAndPossessiveVariants() {
        let matcher = makeMatcher()

        let pluralWindow: [DictionaryMatcher.Token] = [
            .init(raw: "cue", normalized: "cue", range: NSRange(location: 0, length: 3), phonetic: "K"),
            .init(raw: "boards", normalized: "boards", range: NSRange(location: 4, length: 6), phonetic: "BRDZ"),
        ]

        let pluralForms = matcher.splitJoinForms(from: pluralWindow)
        #expect(pluralForms.contains(where: { $0.normalized == "cueboards" && !$0.singularizedSecondToken && $0.replacementSuffix.isEmpty }))
        #expect(pluralForms.contains(where: { $0.normalized == "cueboard" && $0.singularizedSecondToken && $0.replacementSuffix.isEmpty }))

        let possessiveWindow: [DictionaryMatcher.Token] = [
            .init(raw: "cue", normalized: "cue", range: NSRange(location: 0, length: 3), phonetic: "K"),
            .init(raw: "board's", normalized: "board's", range: NSRange(location: 4, length: 7), phonetic: "BRDZ"),
        ]

        let possessiveForms = matcher.splitJoinForms(from: possessiveWindow)
        #expect(possessiveForms.contains(where: { $0.normalized == "cueboard" && !$0.singularizedSecondToken && $0.replacementSuffix == "'s" }))
    }

    @Test
    func singleTokenPossessiveObservedFormsIncludeStemVariant() {
        let matcher = makeMatcher()

        let forms = matcher.observedFormsForWindow(
            tokenCount: 1,
            observedNormalized: "cueboard's",
            observedPhonetic: "KBRDZ"
        )

        #expect(forms.contains(where: { $0.normalized == "cueboard's" && $0.replacementSuffix.isEmpty }))
        #expect(forms.contains(where: { $0.normalized == "cueboard" && $0.replacementSuffix == "'s" }))
    }

    @Test
    func textNormalizationMatchesExistingBehavior() {
        #expect(TextNormalization.normalizedPhrase("  Cue—Board!!! ") == "cue board")
        #expect(TextNormalization.normalizedPhrase("Crème Brûlée") == "creme brulee")
        #expect(TextNormalization.normalizedToken("Cue Board") == "cueboard")
        #expect(TextNormalization.normalizedToken("  ") == "")
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
