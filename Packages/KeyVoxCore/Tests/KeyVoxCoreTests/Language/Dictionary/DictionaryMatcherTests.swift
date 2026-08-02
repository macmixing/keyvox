import Foundation
import XCTest
@testable import KeyVoxCore

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

    func testCorrectsIdentitySentenceForTwoTokenNameNearMissWithA() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "My name is Dom Espacito.")
        XCTAssertEqual(result.text, "My name is Dom Esposito.")
    }

    func testCorrectsIdentitySentenceForTwoTokenNameNearMissWithO() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "My name is Dom Espocito.")
        XCTAssertEqual(result.text, "My name is Dom Esposito.")
    }

    func testCorrectsSingleTokenBrandNearMissWithoutPromptHinting() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "TaskVox")])

        let result = matcher.apply(to: "Have you heard of Taskbox?")
        XCTAssertEqual(result.text, "Have you heard of TaskVox?")
    }

    func testCorrectsStylizedSingleTokenBrandNearMissInSentence() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "KeyVox")])

        let result = matcher.apply(to: "My app is called Keybox.")
        XCTAssertEqual(result.text, "My app is called KeyVox.")
    }

    func testCorrectsStylizedSingleTokenBrandWhenWhisperSplitsToken() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "KeyVox")])

        let result = matcher.apply(to: "My app is called key box.")
        XCTAssertEqual(result.text, "My app is called KeyVox.")
    }

    func testDoesNotCollapseOrdinaryTwoWordPhraseIntoAnchoredStylizedSplitJoinMatch() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "KeyVox")])

        let result = matcher.apply(to: "I added key value storage.")
        XCTAssertEqual(result.text, "I added key value storage.")
    }

    func testCorrectsStylizedSingleTokenBrandNearMissWithRuntimeLexicon() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "KeyVox")])

        let result = matcher.apply(to: "My app is called Keybox.")
        XCTAssertEqual(result.text, "My app is called KeyVox.")
    }

    func testCorrectsStylizedSingleTokenBrandNearMissBeforeTitlecaseProductContext() {
        let matcher = makeRuntimeMatcher()
        let entries = DictionaryBuiltInEntries.effectiveEntries(merging: [])
        matcher.rebuildIndex(entries: entries)

        let result = matcher.apply(to: "Yeah, the Keybox Core package.")

        XCTAssertEqual(result.text, "Yeah, the KeyVox Core package.")
    }

    func testRuntimeMatcherDoesNotRewriteOrdinaryMergedTokenPrefixIntoStylizedSingleTokenBrand() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "KeyVox")])

        let result = matcher.apply(to: "KeyValue Storage")
        XCTAssertEqual(result.text, "KeyValue Storage")
    }

    func testCorrectsTwoTokenNameNearMissWithRuntimeLexicon() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "My name is Dom Espacito.")
        XCTAssertEqual(result.text, "My name is Dom Esposito.")
    }

    func testCorrectsTwoTokenNameNearMissVariantWithRuntimeLexicon() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "Dom Espicido.")
        XCTAssertEqual(result.text, "Dom Esposito.")
    }

    func testDoesNotRewriteChatGotVariantsAsChatGPT() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "ChatGPT")])

        let unrelatedInputs = [
            "But as that got better, this got worse.",
            "But as chat got better, this got worse.",
            "But as chat GOT better, this got worse.",
            "But as THAT, GOT better, this got worse.",
            "But as chat G O T better, this got worse.",
        ]
        for input in unrelatedInputs {
            XCTAssertEqual(matcher.apply(to: input).text, input)
        }
        XCTAssertEqual(matcher.apply(to: "I used chat gpt.").text, "I used ChatGPT.")
        XCTAssertEqual(matcher.apply(to: "I used chat G P T.").text, "I used ChatGPT.")
        XCTAssertEqual(
            matcher.apply(to: "But as chat GBT got better, this got worse.").text,
            "But as ChatGPT got better, this got worse."
        )
    }

    func testSpelledUppercaseSequencesRequireMatchingPronunciation() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "DataAPI")])

        let mismatchedTail = "The data APT changed."
        XCTAssertEqual(matcher.apply(to: mismatchedTail).text, mismatchedTail)
        XCTAssertEqual(matcher.apply(to: "The data api changed.").text, "The DataAPI changed.")

        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "APIClient")])
        let mismatchedHead = "The APT client changed."
        XCTAssertEqual(matcher.apply(to: mismatchedHead).text, mismatchedHead)
        XCTAssertEqual(matcher.apply(to: "The api client changed.").text, "The APIClient changed.")

        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "DataAPIClient")])
        let mismatchedMiddle = "The data APT client changed."
        XCTAssertEqual(matcher.apply(to: mismatchedMiddle).text, mismatchedMiddle)
        XCTAssertEqual(matcher.apply(to: "The data api client changed.").text, "The DataAPIClient changed.")

        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "NASA")])
        let mismatchedWholeEntry = "I worked with NABSA."
        XCTAssertEqual(matcher.apply(to: mismatchedWholeEntry).text, mismatchedWholeEntry)
        XCTAssertEqual(matcher.apply(to: "I worked with NASSA.").text, "I worked with NASA.")
        XCTAssertEqual(matcher.apply(to: "I worked with nasa.").text, "I worked with NASA.")
    }

    func testCompressedTailFallbackDoesNotRewriteUnrelatedThreeTokenSpan() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "Do not respond to me.")
        XCTAssertEqual(result.text, "Do not respond to me.")
    }

    func testCorrectsStylizedSingleTokenNameNearMissWithRuntimeLexicon() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "AirRack")])

        let result = matcher.apply(to: "My name is Erak.")
        XCTAssertEqual(result.text, "My name is AirRack.")
    }

    func testCorrectsStylizedSingleTokenCommonNameNearMissWithRuntimeLexicon() {
        let matcher = makeRuntimeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "AirRack")])

        let result = matcher.apply(to: "My name is Eric.")
        XCTAssertEqual(result.text, "My name is AirRack.")
    }

    func testDoesNotReplaceCommonProseWordWithStylizedDictionaryEntry() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "AirRack")])

        let result = matcher.apply(to: "This kind of thing does work pretty good to an extent.")
        XCTAssertEqual(result.text, "This kind of thing does work pretty good to an extent.")
    }

    func testDoesNotRewriteTitlecasePlaceNameTailIntoStylizedDictionaryEntry() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "AirRack")])

        let result = matcher.apply(to: "Have you ever been to New York?")
        XCTAssertEqual(result.text, "Have you ever been to New York?")
    }

    func testCorrectsStylizedSingleTokenNearMissAndInfersPossessiveSuffix() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "AirRack")])

        let result = matcher.apply(to: "ARAX YouTube channel is big.")
        XCTAssertEqual(result.text, "AirRack's YouTube channel is big.")
    }

    func testCorrectsStylizedSplitJoinPossessiveNearMiss() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "AirRack")])

        let result = matcher.apply(to: "Have you been to Air Act's apartment in downtown LA?")
        XCTAssertEqual(result.text, "Have you been to AirRack's apartment in downtown LA?")
    }

    func testDoesNotCollapseWebsiteDomainIntoStylizedDictionaryEntry() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "KeyVox")])

        let result = matcher.apply(to: "www.KeyVox.app")
        XCTAssertEqual(result.text, "www.KeyVox.app")
    }

    func testCorrectsTwoTokenNameNearMissWithImplicitPossessiveSuffix() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "Hey, that's Dom Especitos House.")
        XCTAssertEqual(result.text, "Hey, that's Dom Esposito's House.")
    }

    func testCorrectsMiddleInitialThreeTokenPossessiveNearMiss() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Dom Esposito")])

        let result = matcher.apply(to: "That's Dom S. Bacito's house.")
        XCTAssertEqual(result.text, "That's Dom Esposito's house.")
    }

    func testCorrectsCompressedTailThreeTokenNearMissForTwoTokenEntry() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Mister PinupCA")])

        let result = matcher.apply(to: "He lives right next door to Mr. Pinnup, CA.")
        XCTAssertEqual(result.text, "He lives right next door to Mister PinupCA.")
    }

    func testCorrectsBothThreeTokenNamePatternsInSameParagraph() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "Mister PinupCA"),
            DictionaryEntry(phrase: "Dom Esposito"),
        ])

        let result = matcher.apply(
            to: "That's Dom S. Bacito's house. He lives right next door to Mr. Pinnup, CA."
        )
        XCTAssertEqual(
            result.text,
            "That's Dom Esposito's house. He lives right next door to Mister PinupCA."
        )
    }

    func testCorrectsBrandAndNameNearMissesInSameSentenceWithRuntimeLexicon() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "KeyVox"),
            DictionaryEntry(phrase: "Dom Esposito"),
        ])

        let result = matcher.apply(to: "My app is called Keyvox and my name is Dom Espacito.")
        XCTAssertEqual(result.text, "My app is called KeyVox and my name is Dom Esposito.")
    }

    func testDoesNotConsumeConjunctionAfterExactSingleTokenBrandInSplitJoinPath() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "Cueboard"),
            DictionaryEntry(phrase: "KeyVox"),
            DictionaryEntry(phrase: "MrBeast"),
        ])

        let result = matcher.apply(
            to: "I love the app cueboard. I also really love KeyVox, and I think MrBeast is awesome."
        )

        XCTAssertEqual(
            result.text,
            "I love the app Cueboard. I also really love KeyVox, and I think MrBeast is awesome."
        )
    }

    func testDoesNotConsumeNounAfterExactSingleTokenBrandInSplitJoinPath() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "KeyVox"),
        ])

        let result = matcher.apply(to: "I'm going to catch a KeyVox bug here or there.")

        XCTAssertEqual(result.text, "I'm going to catch a KeyVox bug here or there.")
    }

    func testDisambiguatesCommonWordBrandTailToCorrectDictionaryEntryWithRuntimeLexicon() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "KeyVox"),
            DictionaryEntry(phrase: "Dom Esposito"),
            DictionaryEntry(phrase: "Cueboard"),
        ])

        let result = matcher.apply(
            to: "I'm using an app called Keybox from Dom Espicito, the creator of Keyboard."
        )
        XCTAssertEqual(
            result.text,
            "I'm using an app called KeyVox from Dom Esposito, the creator of Cueboard."
        )
    }

    func testPreservesFromBeforeExactTwoTokenNameWhileNormalizingOtherBrand() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "KeyVox"),
            DictionaryEntry(phrase: "Dom Esposito"),
            DictionaryEntry(phrase: "Cueboard"),
        ])

        let result = matcher.apply(
            to: "I created an app called KeyVox from Dom Esposito, the creator of cueboard."
        )
        XCTAssertEqual(
            result.text,
            "I created an app called KeyVox from Dom Esposito, the creator of Cueboard."
        )
    }

    func testCorrectsHyphenatedSingleLetterBrandTailAlongsideNameCorrection() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "Dom Esposito"),
            DictionaryEntry(phrase: "Cueboard"),
        ])

        let result = matcher.apply(
            to: "Dom Espacito is the creator of Q-Board."
        )
        XCTAssertEqual(
            result.text,
            "Dom Esposito is the creator of Cueboard."
        )
    }

    func testCorrectsSpacedSingleLetterPronunciationToSingleDictionaryTerm() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "Have you ever heard of Q Board?")

        XCTAssertEqual(result.text, "Have you ever heard of Cueboard?")
    }

    func testDoesNotReplaceKeyboardWithDictionaryBrandWhenWordAlreadyLexiconKnown() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "I love typing on this keyboard.")
        XCTAssertEqual(result.text, "I love typing on this keyboard.")
    }

    func testDoesNotReplaceKeyboardPluralInGenericProse() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "These new MacBooks have great keyboards.")
        XCTAssertEqual(result.text, "These new MacBooks have great keyboards.")
    }

    func testDoesNotReplaceKnownNameWithStylizedDictionaryEntry() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MiGo")])

        let result = matcher.apply(to: "Spot check something like Monique.")
        XCTAssertEqual(result.text, "Spot check something like Monique.")
    }

    func testDoesNotReplaceUnrelatedWordsWithStylizedPluralEntry() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MiGo")])

        let result = matcher.apply(to: "Everything on main goes through another.")

        XCTAssertEqual(result.text, "Everything on main goes through another.")
    }

    func testCorrectsStylizedEntryInNounIntroducedTitlecaseContext() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MiGo")])

        let result = matcher.apply(to: "Have you checked out my app Mego lately? It's pretty cool.")

        XCTAssertEqual(result.text, "Have you checked out my app MiGo lately? It's pretty cool.")
    }

    func testCorrectsStylizedEntrySplitIntoShortTokensInNounIntroducedContext() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MiGo")])

        let result = matcher.apply(to: "Have you checked out my app me go lately? It's pretty cool.")

        XCTAssertEqual(result.text, "Have you checked out my app MiGo lately? It's pretty cool.")
    }

    func testCorrectsStylizedEntrySplitIntoShortTokensAfterParticle() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MiGo")])

        let result = matcher.apply(to: "Have you checked out me go lately?")

        XCTAssertEqual(result.text, "Have you checked out MiGo lately?")
    }

    func testContextualShortTokenSplitRejectsCommonObservedWords() {
        let lexicon = FakeLexicon(
            pronunciations: [
                "me": "M",
                "go": "K",
                "mego": "MK",
                "migo": "MK",
            ],
            commonWords: ["me", "go"]
        )
        let matcher = DictionaryMatcher(
            lexicon: lexicon,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MiGo")])

        let input = "Have you checked out my app me go lately?"
        let result = matcher.apply(to: input)

        XCTAssertEqual(result.text, input)
    }

    func testCorrectsStylizedTitlecaseListItemWithIndependentPeerSupport() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "KeyVox"),
            DictionaryEntry(phrase: "MiGo"),
            DictionaryEntry(phrase: "Cueboard"),
        ])

        let result = matcher.apply(
            to: "I have three apps available right now. Keybox, Mego, and Cueboard."
        )

        XCTAssertEqual(
            result.text,
            "I have three apps available right now. KeyVox, MiGo, and Cueboard."
        )
    }

    func testTitlecaseKnownWordsResistRandomStylizedDictionaryEntries() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "HouZe"),
            DictionaryEntry(phrase: "MarKit"),
            DictionaryEntry(phrase: "PeepL"),
            DictionaryEntry(phrase: "ThynG"),
            DictionaryEntry(phrase: "Worq"),
            DictionaryEntry(phrase: "NayMe"),
            DictionaryEntry(phrase: "PlASe"),
            DictionaryEntry(phrase: "TyMe"),
            DictionaryEntry(phrase: "WaTerz"),
        ])

        let samples = [
            "The House was quiet.",
            "We met near the Market.",
            "Those People were early.",
            "That Thing was broken.",
            "The Work was finished.",
            "Her Name was listed.",
            "The Place was closed.",
            "Their Time was limited.",
            "The Water was cold.",
        ]

        for sample in samples {
            XCTAssertEqual(matcher.apply(to: sample).text, sample)
        }
    }

    func testReplacesCommonWordInOwnershipPredicateContextForStylizedEntry() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "My new iPhone has keyboard installed on it.")
        XCTAssertEqual(result.text, "My new iPhone has Cueboard installed on it.")
    }

    func testKeepsTitlecaseCommonWordInStructuralContextWithoutPeerSupport() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "My new iPhone has Keyboard installed on it.")
        XCTAssertEqual(result.text, "My new iPhone has Keyboard installed on it.")
    }

    func testKeepsCommonWordKeyboardInProseWhenBrandMentionAlsoExists() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "Dom Esposito"),
            DictionaryEntry(phrase: "Cueboard"),
        ])

        let result = matcher.apply(
            to: "Dom Esposito is the creator of Cueboard and I love typing on this keyboard."
        )
        XCTAssertEqual(
            result.text,
            "Dom Esposito is the creator of Cueboard and I love typing on this keyboard."
        )
    }

    func testKeepsCommonWordKeyboardInProseWhenBrandMentionIsSecondClause() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "Dom Esposito"),
            DictionaryEntry(phrase: "Cueboard"),
        ])

        let result = matcher.apply(
            to: "I love typing on this keyboard and Dom Esposito is the creator of Cueboard."
        )
        XCTAssertEqual(
            result.text,
            "I love typing on this keyboard and Dom Esposito is the creator of Cueboard."
        )
    }

    func testKeepsCommonWordKeyboardTypoInProseWhenBrandMentionIsSecondClause() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "Dom Esposito"),
            DictionaryEntry(phrase: "Cueboard"),
        ])

        let result = matcher.apply(
            to: "I love typing on this keybaord and Dom Esposito is the creator of Cueboard."
        )
        XCTAssertEqual(
            result.text,
            "I love typing on this keybaord and Dom Esposito is the creator of Cueboard."
        )
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

    func testSplitJoinAllowsShortTokenWhenJoinExactlyMatchesDictionaryEntry() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MrBeast")])

        let result = matcher.apply(to: "Is that Mr. Beast over there?")
        XCTAssertEqual(result.text, "Is that MrBeast over there?")
    }

    func testSplitJoinAllowsShortTokenExactJoinForInitialedBrand() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "MrD")])

        let result = matcher.apply(to: "Is that Mr. D over there?")
        XCTAssertEqual(result.text, "Is that MrD over there?")
    }

    func testMergedTokenReplacesWithTwoTokenDictionaryPhrase() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Mister PinupCA")])

        let result = matcher.apply(to: "MrBeast went to McDonald's to get some McNuggets with MrPinupCA.")
        XCTAssertEqual(result.text, "MrBeast went to McDonald's to get some McNuggets with Mister PinupCA.")
    }

    func testMergedTokenDoesNotReplaceWhenPrefixIsNotSimilar() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Mister PinupCA")])

        let result = matcher.apply(to: "MrBeast went to McDonald's to get some McNuggets with MapPinupCA.")
        XCTAssertEqual(result.text, "MrBeast went to McDonald's to get some McNuggets with MapPinupCA.")
    }

    func testPluralSecondTokenCanJoinForBrand() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "this is cue boards")
        XCTAssertTrue(result.text == "this is Cueboards")
    }

    func testSplitJoinInfersPossessive() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Cueboard")])

        let result = matcher.apply(to: "this is a test of cue boards abilities")
        XCTAssertTrue(result.text == "this is a test of Cueboard's abilities")
    }

    func testSplitJoinPreservesPluralForSingularDictionaryEntry() {
        let lexicon = FakeLexicon(pronunciations: [
            "sub": "SB",
            "cue": "K",
            "cues": "KZ",
            "subcue": "SBK",
            "subcues": "SBKZ",
        ])
        let matcher = DictionaryMatcher(lexicon: lexicon, encoder: PhoneticEncoder(), scorer: .balanced)
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "subcue")])

        let result = matcher.apply(to: "you make sub cues.")
        XCTAssertEqual(result.text, "you make subcues.")
    }

    func testCorrectsQueueHomophonesForCueAndSubcueEntries() {
        let matcher = DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "Cueboard"),
            DictionaryEntry(phrase: "cue"),
            DictionaryEntry(phrase: "subcue"),
        ])

        let result = matcher.apply(to: "Inside of the app cue board, you can make queues and sub queues.")
        XCTAssertEqual(result.text, "Inside of the app Cueboard, you can make cues and subcues.")
    }

    func testDoesNotReplaceUnrelatedPluralWordWithSingularCueEntry() {
        let matcher = makeRuntimeMatcher()
        let entries = DictionaryBuiltInEntries.effectiveEntries(
            merging: [DictionaryEntry(phrase: "cue")]
        )
        matcher.rebuildIndex(entries: entries)

        let input = "The gear should only be spinning when data is actually being transmitted, not when empty checks are running."
        let result = matcher.apply(to: input)

        XCTAssertEqual(result.text, input)
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

    func testMatcherNormalizesSpokenEmailAddress() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "dom@example.com")])

        let result = matcher.apply(to: "Dom at example.com")
        XCTAssertEqual(result.text, "dom@example.com")
    }

    func testMatcherNormalizesMultipleEmailAddressesInSentence() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ])

        let result = matcher.apply(
            to: "You can reach me at Dom at example.com or kathy@example.com, either of those are fine."
        )
        XCTAssertEqual(result.text, "You can reach me at dom@example.com or kathy@example.com, either of those are fine.")
    }

    func testMatcherNormalizesTwoSpokenEmailAddressesInSentence() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "dom@example.com"),
            DictionaryEntry(phrase: "kathy@example.com"),
        ])

        let result = matcher.apply(
            to: "You can reach me at Dom at example.com or kathy at example.com, either of those are fine."
        )
        XCTAssertEqual(result.text, "You can reach me at dom@example.com or kathy@example.com, either of those are fine.")
    }

    func testMatcherNormalizesOvercapturedSpokenDomainWithPronounOverflow() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "kathy@example.com")])

        let result = matcher.apply(
            to: "Please email kathy at example.com.you can reach me there anytime."
        )
        XCTAssertEqual(result.text, "Please email kathy@example.com you can reach me there anytime.")
    }

    func testMatcherNormalizesOvercapturedSpokenDomainWithNumberWordOverflow() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "dom@example.com")])

        let result = matcher.apply(
            to: "Send it to dom at example.com.thirteen people should receive it."
        )
        XCTAssertEqual(result.text, "Send it to dom@example.com thirteen people should receive it.")
    }

    func testMatcherPreservesSentencePeriodAfterSpokenEmailWithOverflow() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "person@example.com")])

        let result = matcher.apply(
            to: "My email address is person at example.com. And this sentence follows it."
        )
        XCTAssertEqual(
            result.text,
            "My email address is person@example.com. And this sentence follows it."
        )
    }

    func testMatcherNormalizesSpokenEmailWhenDomainHostIsNearDictionaryMatch() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "zackmorbi@rider.com")])

        let result = matcher.apply(to: "Zack Morby at writer.com")
        XCTAssertEqual(result.text, "zackmorbi@rider.com")
    }

    func testMatcherNormalizesSpokenEmailWhenDomainIncludesSpacedDot() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "zackmorbi@rider.com")])

        let result = matcher.apply(to: "Zack Morby at writer. Com")
        XCTAssertEqual(result.text, "zackmorbi@rider.com")
    }

    func testMatcherNormalizesSpokenEmailWhenDomainUsesWordDot() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "person@example.com")])

        let result = matcher.apply(to: "Person at example dot com.")
        XCTAssertEqual(result.text, "person@example.com")
    }

    func testMatcherPrefersExactSpokenDomainWhenItExistsInDictionary() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "zackmorbi@rider.com"),
            DictionaryEntry(phrase: "zackmorby@writer.com"),
        ])

        let result = matcher.apply(to: "Zack Morby at writer.com")
        XCTAssertEqual(result.text, "zackmorby@writer.com")
    }

    func testMatcherNormalizesStandaloneUrlLikeUtteranceToDictionaryEmail() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "zackmorbi@rider.com")])

        let result = matcher.apply(to: "www. Zackmorbi. Com")
        XCTAssertEqual(result.text, "zackmorbi@rider.com")
    }

    func testMatcherDoesNotNormalizeStandaloneUrlLikeUtteranceWhenAmbiguous() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [
            DictionaryEntry(phrase: "zackmorbi@rider.com"),
            DictionaryEntry(phrase: "zackmorby@writer.com"),
        ])

        let result = matcher.apply(to: "www. Zackmorb. Com")
        XCTAssertEqual(result.text, "www. Zackmorb. Com")
    }

    func testMatcherStripsTerminalPunctuationForStandaloneLiteralEmail() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "dom@example.com")])

        let result = matcher.apply(to: "dom@example.com.")
        XCTAssertEqual(result.text, "dom@example.com")
    }

    func testMatcherStripsTerminalPunctuationForStandaloneWebsiteWithoutDictionaryMatch() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [])

        let result = matcher.apply(to: "www.example.com.")
        XCTAssertEqual(result.text, "www.example.com")
    }

    func testMatcherConsumesTrailingSuffixTokenWhenFinalDictionaryTokenIsSplit() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [DictionaryEntry(phrase: "Mister PinupCA")])

        let result = matcher.apply(to: "What happened to Mister Pinup CA? Did he leave early?")
        XCTAssertEqual(result.text, "What happened to Mister PinupCA? Did he leave early?")
    }

    func testMatcherPreservesTerminalPunctuationForShortProseWithAtDomainPattern() {
        let matcher = makeMatcher()
        matcher.rebuildIndex(entries: [])

        let result = matcher.apply(to: "Contact me at example.com.")
        XCTAssertEqual(result.text, "Contact me at example.com.")
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
            "mister": "MSTR",
            "mr": "MR",
            "beast": "BST",
            "mrbeast": "MRBST",
            "d": "D",
            "mrd": "MRD",
            "pinup": "PNP",
            "pinupca": "PNPK",
            "ca": "K",
        ])

        return DictionaryMatcher(lexicon: lexicon, encoder: PhoneticEncoder(), scorer: .balanced)
    }

    private func makeRuntimeMatcher() -> DictionaryMatcher {
        DictionaryMatcher(
            lexicon: PronunciationLexicon.shared,
            encoder: PhoneticEncoder(),
            scorer: .balanced
        )
    }
}
