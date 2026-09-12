# Android Core linguistic bakeoff

## Decision

The recorded cross-platform bakeoff ran the same 582 shared Core tests and
expectations on Android and Apple; both platforms passed all 582. The selected
Android implementation combines the existing
first-party Swift perceptron predictor, focused portable semantic resolution, and
the unchanged WordNet 3.0 lexical indexes. Apple continues to select
`AppleLinguisticAnalyzer` and its NaturalLanguage-backed capabilities.

The Android engine explicitly injects the selected analyzer. A production log
identifies it as:

```text
linguistic-capabilities=perceptron+wordnet-3.0 default-language=en
```

This implementation does not replace or regenerate KeyVox's pronunciation
lexicon, common-word resource, or user dictionary. WordNet supplies only lexical
part-of-speech membership used at ambiguous Core decisions.

## Complete-suite comparison

Every executable configuration used the same test sources, fixtures, and
expectations. No failure was skipped, weakened, deleted, or platform-conditioned.
The suite grew from 572 to 582 through ten portable regression tests discovered
during the bakeoff and initial review. Three later address-boundary regressions
bring the current Apple-host suite to 585 tests; they are not part of the recorded
Android bakeoff result. The sixth bakeoff regression proves Whisper segment assembly uses the
injected analyzer. The seventh proves an explicit unsupported processing language
reaches language-less internal stages. The eighth distinguishes a terminal
two-title-word address from a two-title-word quantity modifier in prose. The ninth
and tenth reject address candidates with a plural semantic head or a continuing
nominal phrase, without embedding fixture vocabulary in production policy.

| Configuration | Tests passed | Failed cases | Failed assertions | Time | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| Apple implementation, initial baseline | 572 / 572 | 0 | 0 | — | Reference green |
| Unicode/default portable baseline | 496 / 572 | 76 | 122 | 12.465 s | Rejected |
| Raw averaged perceptron | 525 / 572 | 47 | 54 | 10.017 s | Rejected |
| Focused semantics + perceptron | 573 / 575 | 2 | 2 | 6.992 s | Rejected |
| Focused semantics + perceptron + WordNet 3.0, pre-review | 577 / 577 | 0 | 0 | 7.118 s | Superseded wiring evidence |
| Selected implementation, final Apple | 582 / 582 | 0 | 0 | 10.945 s | Reference green |
| Selected implementation, final Android | 582 / 582 | 0 | 0 | 6.801 s | Android green |

The raw perceptron fixed 34 baseline failures, retained 42, and introduced five.
Focused contextual resolution repaired its retained and introduced errors without
embedding fixture vocabulary in production logic. WordNet lexical evidence fixed
the final two dictionary ambiguities.

## Candidate matrix

| Combination | Core semantics | Full-suite result | Runtime/distribution | Languages and fallback | Portability/maintenance |
| --- | --- | --- | --- | --- | --- |
| Unicode/default portable | Boundaries only | 496 / 572 | No model cost | Unicode boundaries for all requests; semantic features unavailable | Smallest, but insufficient |
| Raw NLTK averaged perceptron | Statistical Penn roles | 525 / 572 | 5.6 MB model directory | English only; other languages receive boundaries and unavailable roles | Portable Swift predictor, but raw tags do not match Core decisions |
| Focused semantics + perceptron | Contextual roles, name identity, noun inflection, numeric date/address protection | 573 / 575 | Perceptron assets only | English semantics; deterministic conservative missing-language behavior | Focused and portable; two lexical ambiguities remained |
| Focused semantics + perceptron + WordNet 3.0 | Complete selected Core capability set | 582 / 582 | 11.7 MB raw assets; 4.19 MB compressed APK resources | English semantic model; Unicode and conservative structural fallback elsewhere | First-party Swift, no new runtime or transitive code dependency; suitable for future host validation |

All configurations operate offline and deterministically from pinned local assets.
Ranges are expressed in UTF-16, matching Core and Apple contracts. Explicit
unsupported languages never silently select English semantics. They retain Unicode
boundaries and explicit unavailable features, plus the structural numeric fallback
covered by shared tests. Calls with no selected or detected language use the Android
host's documented English default.

Apple exposes lemmas through its existing implementation. Android deliberately
reports general lemma support unavailable: Core's observed decisions require
lexical roles, name identity, and noun inflection, which the portable analyzer
supplies directly. The green complete suite is Core behavioral parity, not a claim
that the portable provider recreates every NaturalLanguage API.

## Screened alternatives

These were credible leads, but were not advanced into executable candidates after
the selected existing portable stack reached complete Core parity. Adding their
runtime and model footprint would therefore have had no demonstrated behavioral
benefit.

| Alternative | Relevant capability | Reason not integrated |
| --- | --- | --- |
| Apache OpenNLP | POS, lemmatization, names, tokenization across published model families | Adds a JVM/runtime bridge and separately versioned models. OpenNLP recommends training application models for non-testing use, so each model and training provenance would require a separate accuracy and licensing gate. |
| Microsoft Recognizers-Text | Numbers, dates, times, and units | Does not provide the roles, inflection, or names consumed by the remaining Core failures; Java support is incomplete and its date/time package adds dependencies. |
| spaCy | Broad statistical NLP | Requires a Python/native runtime and separately licensed/versioned pipelines, a disproportionate distribution and maintenance cost after the portable Swift solution reached complete Core parity. |

## Semantic and held-out evidence

Instrumentation records every selected analyzer invocation and its requested
features, language, token ranges, roles, name identities, noun inflection, and
numeric protected ranges. This proved both the test runner and real Android engine
used the selected implementation.

Two representative held-out paragraphs were processed on Apple and Android. The
final outputs matched exactly:

```text
During 2019, Élodie shipped 3,400 ceramic vessels to 742 Evergreen Avenue on March 14, 2028. Those 2,400 sample containers arrived after they checked over it twice. If Jordan brings another 1,800 units, record 2,029 as the reference year.
```

```text
Élodie a envoyé 3,400 objets à Zürich pendant 2019.
```

The first exposed a quantity before an adjective and plural noun. The second
exposed year protection when grammatical roles are unavailable. Both were fixed
structurally, then preserved with generated portable tests. No example word,
phrase, or English surface string was added to production policy.

## Performance and distribution cost

Measurements were taken on the connected Android device from the same model-selected
runner and final protected NPU application.

| Measurement | Perceptron only | Selected combination |
| --- | ---: | ---: |
| Cold analyzer initialization | 350.8 ms | 599.9 ms |
| RSS increase | 35,548 KB | 38,784 KB |
| Increment from WordNet | — | +249.1 ms, +3,236 KB |
| Warm analysis, 1,384 calls | — | p50 0.231 ms, p95 0.884 ms, mean 0.377 ms, max 9.008 ms |

The perceptron directory occupies 5,600 KB and WordNet 6,168 KB on disk. Their APK
resource entries total 12,009,770 raw bytes and 4,187,815 compressed bytes. The
final signed protected debug APK is 64,682,919 bytes. Its SHA-256 is
`bb391c8df12aa26e4858c838791aa5b6c0674b2c137529190f25161467270182`.

## Real Android path

The final package retained application ID `org.keyvox.android`, version 1, and the
installed signing certificate. It was installed in place with `adb install -r`;
no uninstall, package clear, or storage reset occurred. The protected build
contained the QNN provider and DSP payload. Device logs from the final run recorded
successful QNN completion at 148.427 ms and 137.842 ms.

Existing saved audio passed through actual Base inference and Core in the installed
engine. The observed processed output was:

```text
Welcome to KeyVox Speak. I can speak any text copy.
```

The measured path reported 0.378 ms audio read, 242.159 ms model warmup,
441.253 ms inference, 3,053.619 ms total pipeline time, and 2,567.119 ms waiting
for postprocessor preparation. The same log contained the selected-capability
identity above, proving the real dictation pipeline—not only the test executable—
used the perceptron and WordNet provider.

## Licensing and provenance gate

The selected solution adds no runtime code dependency or transitive dependency.
KeyVox's source remains MIT. The host owns and packages two independently licensed
data bundles:

| Asset | Exact source/version | License | Distribution obligations |
| --- | --- | --- | --- |
| NLTK averaged perceptron English JSON | `nltk_data` commit `329f92961f6b73027e4b5c975554df7094b2b29e`; archive SHA-256 `6025f530624335c67d6547d44757b357b4e79bae030a0383e9887a92c1718f0b` | MIT | Retain `LICENSE.txt` and the predictor's bundled notice. Upstream metadata identifies English and MIT. The original publication describes WSJ training; no training corpus is distributed. |
| WordNet lexical indexes | WordNet 3.0 official archive; SHA-256 `640db279c949a88f61f851dd54ebbb22d003f8b90b85267042ef85a3781d3a52` | WordNet 3.0 License | Commercial use and distribution are permitted without fee or royalty when the copyright notice and disclaimer are retained on every copy. Do not use Princeton's name in advertising or publicity. |

Only WordNet's unchanged noun, verb, adjective, and adverb index files are
distributed; no corpus, gloss database, binaries, or generated resource is added.
File-level hashes and source URLs are pinned in each model directory's
`sources.lock.json`. Required license texts ship beside the assets. An independent
reviewer must verify these compatibility conclusions before merge.

## Root-cause and resolution record

| Class | Actual cause | Resolution |
| --- | --- | --- |
| Missing capability | Default portable analysis exposed boundaries but no grammatical roles, names, inflection, or semantic numeric protection | Added portable capabilities behind existing boundaries and explicit availability contracts |
| Incorrect result | Raw Penn tags do not directly express Core's contextual distinctions; ambiguous particles, possessives, gerunds, sentence capitalization, punctuation attachment, and noun number produced wrong decisions | Added structural Penn contextual resolution, name identity, and noun inflection |
| Incorrect result | Two dictionary cases remained lexically ambiguous after contextual resolution | Added unchanged WordNet lexical membership as a tie-breaking capability |
| Integration defect | Android engine did not inject the selected analyzer into the production postprocessor | Added Android-owned construction/injection and one-time capability logging |
| Integration defect | The production analyzer initially had no default language; after adding one, explicit unsupported languages were still lost by internal stages that omitted their call-level language | Kept the host-owned English default for an omitted processing language and scoped each postprocessor run to its explicit language so every internal call inherits it; regressions cover both paths |
| Integration defect | Whisper segment-boundary casing read the task-local provider before the injected postprocessor ran | Injected the same analyzer into `WhisperService` and `WhisperSegmentTextAssembler`, with a generated-token regression proving the injected provider is consulted |
| Incorrect result | Portable address protection first required three title-cased words after a street number; broader title-case rules then falsely protected terminal plural quantities and longer titled modifier chains | Reject candidates whose following token continues a nominal phrase, and re-evaluate candidate casing to reject a plural semantic head; preserve the structural fallback when roles are unavailable |
| Integration defect | An Apple-only VoiceActivity binary dependency was unconditional, blocking a clean Android package graph | Restricted the Apple binary target dependency to iOS and macOS |
| Harness limitation | The default Android test executable could not select or trace an alternative provider; historical counts were stale | Added a model-selected runner, exact semantic traces, held-out processing, and cold/warm resource instrumentation |

### Per-failure ledger

The raw perceptron dispositions below account for all 76 baseline failures and
all five failures introduced by that rejected candidate. Every listed case passes
in the selected 582-test configuration. The sixth added regression validates the
injected Whisper segment analyzer; the seventh and eighth validate explicit-language
propagation and the terminal two-word address distinction. The ninth and tenth
validate plural semantic heads and continuing nominal phrases.

| Raw-model disposition | Test case |
| --- | --- |
| Fixed | `DictationPipelineTests.testPipelineEmitsDeterministicParagraphAndListVariants` |
| Fixed | `DictationPipelineTests.testPipelineEmitsDeterministicVariantsWhenParagraphsAndListsAreOff` |
| Fixed | `DictationPipelineTests.testPipelineEmitsListEnabledDeterministicVariantsWhenListsAreOff` |
| Fixed | `DictationPipelineTests.testPipelineEmitsSingleLineDeterministicListVariantsWhenRenderModeIsInline` |
| Fixed | `DictationPipelineTests.testPipelineProcessesAndPastesFormattedText` |
| Fixed | `DictationPipelineTests.testPipelineProvidesDeterministicVariantsToOutputTransformation` |
| Retained | `DictionaryMatcherTests.testCorrectsStylizedEntryInNounIntroducedTitlecaseContext` |
| Retained | `DictionaryMatcherTests.testCorrectsStylizedEntrySplitIntoShortTokensAfterParticle` |
| Fixed | `DictionaryMatcherTests.testCorrectsStylizedEntrySplitIntoShortTokensInNounIntroducedContext` |
| Retained | `DictionaryMatcherTests.testDisambiguatesCommonWordBrandTailToCorrectDictionaryEntryWithRuntimeLexicon` |
| Fixed | `DictionaryMatcherTests.testPreservesCandidateRelativeTrailingPluralBeforeConjunction` |
| Fixed | `DictionaryMatcherTests.testPreservesCandidateRelativeTrailingPluralBeforeVerb` |
| Fixed | `DictionaryMatcherTests.testReplacesCommonWordInOwnershipPredicateContextForStylizedEntry` |
| Fixed | `DictionaryMatcherTests.testSplitJoinInfersPossessive` |
| Fixed | `DictionaryMatcherTests.testSplitJoinInfersPossessiveBeforeAdjectiveNounPhrase` |
| Fixed | `ListFormattingEngineTests.testFormatsDetectedList` |
| Fixed | `ListFormattingEngineTests.testFormatsSpokenListBeforeTimePhraseTrailingSentence` |
| Fixed | `ListFormattingEngineTests.testStripsStructuralCommaFromLongerSpokenListItem` |
| Fixed | `ListPatternDetectorTests.testSplitsShortNominalLastItemFromSentenceStyleCommentary` |
| Fixed | `ListPatternDetectorTests.testStripsStructuralCommaFromLongerSpokenListItem` |
| Fixed | `ListPatternDetectorTests.testStripsTerminalPunctuationFromShortListItems` |
| Fixed | `TerminalPeriodNormalizerTests.testDoesNotAppendPeriodToListOrListItem` |
| Retained | `TerminalPunctuationNormalizerTests.testDoesNotConvertOrdinaryReferences` |
| Fixed | `TerminalPunctuationNormalizerTests.testDoesNotConvertProtectedDeterminerCommandEdges` |
| Fixed | `TerminalPunctuationNormalizerTests.testDoesNotConvertTerminalPunctuationNounPhrases` |
| Fixed | `TranscriptionPostProcessorTests.testAppliesDictionaryCasingBeforeListFormatting` |
| Fixed | `TranscriptionPostProcessorTests.testCapitalizesAndAfterPeriodWhenRestartHasNoSpace` |
| Fixed | `TranscriptionPostProcessorTests.testColonNormalizationStaysCompatibleWithListFormatting` |
| Fixed | `TranscriptionPostProcessorTests.testForceAllCapsAppliesAfterNormalizationPipeline` |
| Fixed | `TranscriptionPostProcessorTests.testForceAllCapsFormatsUppercaseSpokenNumberMarkers` |
| Retained | `TranscriptionPostProcessorTests.testFormatsFourDigitQuantitiesInSentenceWhilePreservingYearReferences` |
| Retained | `TranscriptionPostProcessorTests.testFormatsNounBasedCountQuantityBeyondCommonYearRange` |
| Retained | `TranscriptionPostProcessorTests.testFormatsPartitiveFourDigitQuantitiesWithoutTreatingThemAsYears` |
| Retained | `TranscriptionPostProcessorTests.testFormatsQuantityBeforeConfirmationPhrase` |
| Retained | `TranscriptionPostProcessorTests.testFormatsQuantityBeforeImmediateTimeQualifier` |
| Retained | `TranscriptionPostProcessorTests.testFormatsQuantityLikePluralNounPhrasesAtSentenceStartAndAfterDeterminer` |
| Retained | `TranscriptionPostProcessorTests.testFormatsSentenceFinalDigitQuantitiesAfterAdjectiveModifiers` |
| Fixed | `TranscriptionPostProcessorTests.testFormatsSentenceFinalSpokenQuantitiesAfterAdjectiveModifiers` |
| Retained | `TranscriptionPostProcessorTests.testFormatsSpokenQuantityAfterFillerLikeWhenContextIsQuantity` |
| Retained | `TranscriptionPostProcessorTests.testFormatsSpokenQuantityWithYearLikeValueWhenContextIsQuantity` |
| Retained | `TranscriptionPostProcessorTests.testFormatsStandaloneFourDigitQuantitiesBelowTenThousand` |
| Retained | `TranscriptionPostProcessorTests.testFormatsTotalNumberQuantityBeyondCommonYearRange` |
| Retained | `TranscriptionPostProcessorTests.testFormatsUnqualifiedQuantityBeyondCommonYearRange` |
| Retained | `TranscriptionPostProcessorTests.testKeepsBetweenColinPhraseLiteral` |
| Retained | `TranscriptionPostProcessorTests.testKeepsBetweenColonPhraseLiteral` |
| Fixed | `TranscriptionPostProcessorTests.testKeepsStandaloneColonWordWithoutContext` |
| Fixed | `TranscriptionPostProcessorTests.testListFormattingEnabledStillFormatsWhenExplicitlyTrue` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesCompleteSpokenThousandsWithoutTruncatingTheRemainder` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesLowercasedSpokenThousandsWithoutLeavingResidualWords` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesSpokenHundredsOverOneThousand` |
| Fixed | `TranscriptionPostProcessorTests.testNormalizesSpokenThousandWithAndRemainder` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesSpokenThousandsAndHundredsWithoutTriggeringListFormatting` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesSpokenThousandsInsideSentenceWithoutTouchingDates` |
| Fixed | `TranscriptionPostProcessorTests.testNormalizesSpokenThousandsWithArticleLedHundreds` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesSpokenThousandsWithConjunctionAndTeenTailWithoutLeavingResidualWords` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesSpokenThousandsWithConjunctionAndUnitTailWithoutLeavingResidualWords` |
| Retained | `TranscriptionPostProcessorTests.testNormalizesSpokenThousandsWithFiftyOneTailWithoutLeavingResidualWords` |
| Fixed | `TranscriptionPostProcessorTests.testNormalizesStandaloneSpokenThousandsQuantity` |
| Retained | `TranscriptionPostProcessorTests.testPreservesAddressNumbersWhileFormattingNearbyQuantities` |
| Retained | `TranscriptionPostProcessorTests.testPreservesAdjacentSpokenYearsWithoutGroupingSeparators` |
| Retained | `TranscriptionPostProcessorTests.testPreservesMonthLedDatesAfterDateNormalization` |
| Retained | `TranscriptionPostProcessorTests.testPreservesMonthYearReferencesWhileFormattingFourDigitQuantities` |
| Retained | `TranscriptionPostProcessorTests.testPreservesQuantitiesWhileNormalizingMonthLedDates` |
| Retained | `TranscriptionPostProcessorTests.testPreservesSpokenSinceLikeYearWithoutGroupingSeparator` |
| Retained | `TranscriptionPostProcessorTests.testPreservesSpokenSinceYearWithoutGroupingSeparator` |
| Retained | `TranscriptionPostProcessorTests.testPreservesSpokenYearBeforeConfirmationPhrase` |
| Retained | `TranscriptionPostProcessorTests.testPreservesSpokenYearWhileFormattingNearbySpokenQuantity` |
| Retained | `TranscriptionPostProcessorTests.testPreservesYearFirstSlashedDatesWhileFormattingQuantities` |
| Retained | `TranscriptionPostProcessorTests.testPreservesYearInCounterfactualTemporalClause` |
| Retained | `TranscriptionPostProcessorTests.testPreservesYearModifiersWhileFormattingFourDigitQuantities` |
| Retained | `TranscriptionPostProcessorTests.testPreservesYearReferencesBeforeTerminalQualifiersAcrossNumericPaths` |
| Retained | `TranscriptionPostProcessorTests.testPreservesYearsQuantitiesAndPinNumberAcrossLongNumericGauntlet` |
| Fixed | `TranscriptionPostProcessorTests.testSplitsShortNominalListItemFromTrailingCommentary` |
| Fixed | `TranscriptionPostProcessorTests.testStillFormatsRealListsWhenUsingInOneInTwoPattern` |
| Retained | `WhisperSegmentTextAssemblerTests.testLowercasesIncidentalCapitalAcrossChunkBoundary` |
| Retained | `WhisperSegmentTextAssemblerTests.testLowercasesIncidentalContinuationCapitals` |
| Introduced | `DictionaryMatcherTests.testCorrectsCandidateRelativeTrailingPossessiveForm` |
| Introduced | `TerminalPunctuationNormalizerTests.testConvertsTerminalExclamationCommandAfterClauseEndingInThat` |
| Introduced | `TerminalPunctuationNormalizerTests.testConvertsTerminalQuestionCommandAfterDeterminerPhrase` |
| Introduced | `TranscriptionPostProcessorTests.testConvertsUnpunctuatedExclamationCommandAfterDeterminerPhrase` |
| Introduced | `TranscriptionPostProcessorTests.testNormalizesBareColonAssociationLabel` |

There is no unresolved Core failure in the measured Apple or Android
configuration. Broader multilingual linguistic accuracy and Windows/Linux runtime
execution remain outside this acceptance claim.
