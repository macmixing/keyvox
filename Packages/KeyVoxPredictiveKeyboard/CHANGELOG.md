# Changelog

All notable changes to `KeyVoxPredictiveKeyboard` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared typing prediction and correction behavior within the KeyVox monorepo.

---

## [2.0.0] - 2026-11-26

Typing languages, Apple's letter layouts, and swipe typing: each language the keyboard types in is read from its own folder, English first; each of Apple's letter layouts is bundled as data; and a finger sliding across the letter keys types the word it traces.

### Includes

- `TypingLanguage.bundled(identifier:)` reads one language from `PredictiveData/<identifier>`: its dictionary, context model, rankers, accent overlay, word lists, held-key characters, and spacing character lists, and from its `language.json` the letter rows, the letters single-letter edits try, the vowels a short typed word needs, the always-capitalized words, and the quotation marks.
- `PredictiveEngine(language:)` replaces `EnglishPredictiveEngine()`, and the native engine takes the language's edit letters and vowels instead of its own English ones, counting a short typed word's length in letters.
- `PredictiveTypingSession(language:)`, `HeldKeyCharacters.bundled(for:)`, and the `CharacterList` lists take the language; `WordCasing` and `SmartQuotes` are the language's (`TypingLanguage.casing`, `TypingLanguage.quotes`), with `WordCasing.writingAlwaysCapitalized` in place of `capitalizingPronoun`.
- The words spelled only with capitals come from the language's `KeyVoxLinguistics` list (`CapitalizedSpellings(languageCode:)`).
- `KeyVoxPredictiveKeyboardResources.configure(bundleURL:)` lets a host outside an app bundle, such as the Android engine, point the package at its unchanged resource bundle, as `KeyVoxCoreResources` and `KeyVoxLinguisticsResources` do.
- The English files move to `PredictiveData/en` under plain names: `dictionary/`, `context_model.bin`, `correction_ranker.kvtr`, `completion_ranker.kvtr`, and `autocorrect_decision.kvtr`.
- `PredictiveData/en/dictionary` is rebuilt from SCOWL and OASST1 at pinned revisions and from Tatoeba's English sentences as of its 2026-07-18 export, checked against their recorded SHA-256; besides the words it leaves out as offensive (below), only the order its entries were written in and the write times in its header change.
- `PredictiveData/letter_layouts` holds one file per Apple layout name, with the letter rows of Apple's iOS 27.2 iPhone keyboard: QWERTY, QWERTZ, QWERTZ-German, AZERTY, AZERTY-French, QWERTY-Spanish, QWERTY-Accents, QWERTZ-Accents, and Dvorak. Each row lists its character keys, shift and delete keys, and padding, with their widths in letter keys, and each file says whether a keyboard draws shift and delete across the padding beside them (`shiftAndDeleteFillPadding`): QWERTY does, as English's keyboard always has; the others leave Apple's gap.
- `LetterKeyLayout.bundled(identifier:)` reads one; `LetterKeyLayout` gains its `identifier`, its `rows` (`LetterKeyRow`), its `width` in letter keys, and `shiftAndDeleteFillPadding`, and its `defaultGeometry` places the layout's letters where Apple's keyboard draws them.
- A language's `language.json` names its `defaultLetterLayout` and Apple's `alternativeLetterLayouts` in Apple's order in place of its own letter rows; `TypingLanguage.letterLayout` is the default layout and `TypingLanguage.alternativeLetterLayouts` names the others. English shows QWERTY and lists AZERTY, QWERTZ, and Dvorak.
- `PredictiveKeyboardError.invalidLetterLayout` reports a layout file that does not decode, names another layout, or has rows of different widths.
- `PredictionComputer.swipeWords(for:previousWords:wordCase:limit:)` decodes a swipe's `SwipeTouchSample` path into ranked words, written as typing writes them: text replacement shortcuts expand, the user's words take their entry's form, learned words and learned capitals apply, and `SwipeWordCase` carries the shift state; `swipeCandidates(for:previousWords:)` returns the ranked spellings with their scores.
- The search covers the typing language's dictionary and swipe vocabulary through a memory-mapped key-path trie (`PredictiveData/en/swipe_lexicon.kvsl`, built by `SwipeLexiconBuilder` from `SwipeVocabulary.lexiconWords(of:)`) and the user's own words beside it: KeyVox Dictionary entries with contact names among them, text replacement shortcuts, and offered learned words.
- The bundled English swipe model (`swipe_encoder.kvsw` and `swipe.json`; a model may add an optional `swipe_decoder.kvsd`, which the English one runs without) runs from its memory-mapped fp16 weights with Accelerate's current BLAS interface, and with plain Swift where Accelerate is missing, such as Android; it matches the swipe model tools' reference decoding on swipe.futo.org validation swipes.
- Candidates rank by the model tools' tuned score plus how much likelier the words before make them (`ContextLanguageScorer`); words a swipe cannot tell apart because their key paths are the same, such as "to" and "too", are ordered among themselves: a loop around a key credits each word that has its letter exactly twice there, never one with it three times, and a word adding letters where no loop was read comes after its twins whatever its loops, weighed there, for a doubled letter, only against twins with the same circled letters, and for a tripled one against every twin with it fewer times, whatever the words before (`SwipeKeyLoop`, `loops` in `swipe.json`), and a squiggle over a key, a quick back-and-forth zigzag across it, counts as a loop there in every one of these rules, read only where no plain swipe of the measured ones reads as one (`SwipeKeySquiggle`, `squiggles` in `swipe.json`); a word a loop credits loses to a word on the same keys that doubles a letter where no loop was read and lacks a circled double, when that word is written `misspellingRatio` times as often, so a loop read where the finger merely turned keeps "dropped" rather than "drooped", at the cost of rare circled words such as "fess" giving "fees"; without one, twins the dictionary or swipe vocabulary has are left to their scores and the words before, counted `samePathContextWeight` times among them, unless one is written `misspellingRatio` times as often as the other, which then wins whatever the words before, so "is" never gives "iss", so "as soon" gives "soon", "my son" gives "son", "very good" gives "good", "me too" gives "too", and "turn off" gives "off", while a letter only the user's own words double is never added, so a contact's "Mann" stays "man" whatever the words before, and a word the bundled lexicon and the user's words both have ranks among its twins by the lexicon's spellings; a letter three times or more, or a double against a twin only the user's words have, is added only when that twin is a misspelling written `misspellingRatio` times less often (`SwipeTwinFacts`, `swipe.json`).
- `SwipeGate` decides which fingers are swiping rather than tapping, so fast taps, rolls, and overlapping two-thumb taps stay taps: a finger meeting the swipe threshold is a swipe once it stays down a moment longer or slows into its lift, and one lifting at speed right after the threshold is a tap when another finger lands soon after; `isTraveling` tells a host when a finger that may still swipe has moved far enough to show a swipe beginning, and `touchStopsSwiping` keeps a finger something else took, such as a held key's popup, from swiping while it stays down, so a finger landing beside it never swipes.
- Swipes decode to the English swipe vocabulary (`PredictiveData/en/swipe_vocabulary.txt`), one word per line with its probability on the dictionary's 0-255 scale, likeliest first, built by `Tools/KeyVoxLanguageModel`: 22,459 words people write that the dictionary lacks, from YouTube-Commons, OASST2, and Tatoeba, such as "haha", "hahaha", "omg", "lmao", "cuz", and "anyways", British spellings, and names; typing never offers its words.
- The English swipe vocabulary adds 3,860 words of the sentences in swipe.futo.org's training split that the dictionary and its other words lack, after them at their lowest probability: names such as "Derbyshire" and hyphenated words such as "well-known", written as the sentences write them. With 3,861 of them, before the words left out as offensive, the swipe lexicon held 133,299 words, and on swipe.futo.org's test split, with the words before each swipe, 92.62% of swipes decoded to their word first, from 92.26%.
- Words whose key paths differ only in their first key rank by where the swipe landed and the words before (`SwipeLandingKey`, `landing` in `swipe.json`): every swipe's landing counts, wherever the swipe lifts, each word losing the natural log of how much less likely the landing is for its first key, with landings spread around the key they mean as a bell curve and a few landing anywhere, both measured on swipe.futo.org's validation swipes, so a swipe from "y" to "o" gives "yo" rather than "to" and one from "u" to "s" gives "us" rather than "is", as the system keyboard does, also when it lands off its key's center toward the other key or lifts loosely; a landing halfway between the two keys favors neither. Among such words the words before count `firstKeyContextWeight` rather than the context weight. They only trade places among themselves, after the words before are weighed, so the scores they hold and every ranking outside them stay as scored. Of swipe.futo.org's 67 training and validation swipes of "us", 59 give "us".
- The English dictionary and swipe vocabulary leave out every word that a pinned profanity list's English terms tagged racial or anti-LGBTQ, or religious at strong severity or above, match, with their plural and possessive forms (`Tools/KeyVoxTypingModels/offensive_words.py`): 64 dictionary words, with the 13 word pairs holding them, and 7 swipe vocabulary words, so no swipe gives one. Every other word and its probability stays as it was, the rankers learn from the dictionary as counted and are unchanged, and the swipe lexicon holds 133,228 words, with which swipe.futo.org's validation and test splits measure as before.
- The bundled English swipe model is the encoder fine-tuned a second time for ranking (`r3-ft2` of `Tools/KeyVoxSwipeModel`), the same size and format, with its tuned scoring, the frequency weight lowered so a swipe from one key's center to another's still gives the word on those keys, a context weight of 0.7, and a beam of 200 key-path prefixes. With it and the landing rule, 92.56% of swipe.futo.org's test swipes decode to their word first.
- `PredictiveTypingSession.swipeEdit(word:textBeforeCursor:selectedText:textAfterCursor:)` inserts a swiped word with no space after it, as the system keyboard does, unless a word follows the cursor; a word swiped right after it, or right after a mark a picked word is spaced away from, goes in after a space, and none goes in at the start of the text or after a space. `endsWithSwipedWord(textBeforeCursor:)` tells whether the text before the cursor still ends with what the swipe inserted, the space before a following word included, which a word boundary ends as swiped, inserting only the separator with no autocorrection, revision, or learning; `swipedWordLetterEdit(letter:textBeforeCursor:)` puts a space before a letter tapped right after it, as the system keyboard does, unless the swipe put a space after its word; `forgetSwipedWord()` ends that record, as when the cursor or the field moves; and `previousWords(beforeSwipeAfter:selectedText:)` gives a swipe the words before it, that word among them.
- `PredictiveKeyboardError.invalidSwipeModel` reports a damaged or mismatched swipe model file.

### Notes

- `2.0.0` changes public API: hosts create the engine and the typing session with a `TypingLanguage`, and call `WordCasing` and `SmartQuotes` through it. English typing is unchanged: its dictionary has the same words, word pairs, and three-word sequences at the same probabilities, the correction and completion rankers, the autocorrect decision model, and the accent overlay are the same bytes, and its letters sit where they did.
- The package requires macOS 13.3, the first release with Accelerate's current BLAS interface; the iOS minimum is unchanged.

## [1.1.0] - 2026-11-14

A held key can offer the web endings in a fixed order, as the system keyboard's web address and email keys do.

### Includes

- `HeldKeyCharacters.Direction` gains `centered`: the popup keeps the listed order, the key's own text over the key as far as the keyboard allows, sliding along to stay on it.
- `HeldKeyCharacters.Offer.ownIndex` says where the key's own text is among the characters; it is the first in a popup toward a side.
- The bundled list offers the web endings for the common web ending's key.

### Notes

- `1.1.0` adds public API (`Direction.centered`, `Offer.ownIndex`); existing offers and hosts work unchanged, and a host shows the web endings by looking up the common web ending's key.

---

## [1.0.5] - 2026-11-11

A word typed right before another word is suggested for on its own, as on the system keyboard.

### Includes

- When the user taps every letter of the word before the cursor and another word follows right after it, the bar suggests for the typed letters alone, and a pick replaces only them and keeps the following word.
- A word the cursor was moved into is still suggested for as a whole: `TypedWordTouches` drops its touches when a cursor move puts letters it recorded after the cursor, while deleting a letter keeps the touches of the letters before it; `PredictiveTypingSession.textDidChange` takes the text after the cursor to tell the two apart.

### Notes

- `1.0.5` adds an optional `textAfterCursor` to `PredictiveTypingSession.textDidChange` and an optional `restOfWord` to `TypedWordTouches.synchronize`; existing calls compile unchanged, and keyboard hosts pass the text after the cursor to get the new behavior.

---

## [1.0.4] - 2026-11-06

Capitalized spellings now come from the shared language package.

### Includes

- `EnglishPredictiveEngine.capitalizedSpellings` now uses `CapitalizedSpellings` from `KeyVoxLinguistics`, which owns the bundled list, so the keyboard and dictation share one list.

### Notes

- `1.0.4` moves `CapitalizedSpellings` to `KeyVoxLinguistics`; its API is unchanged, and keyboard hosts that name the type import `KeyVoxLinguistics`.

---

## [1.0.3] - 2026-10-29

A next-word bar that keeps offering three words while the user picks its words in a row, and autocorrection that fixes a real word typed with two keys a key off without dropping a letter the user tapped.

### Includes

- While the user picks from the bar in a row, a word with fewer than three new next words is followed by what usually follows such a word (`UnknownWordFollowers`), after its own next words and before any that would repeat a pick.
- Filling words never repeat a word already on the bar or a pick, by the same rule as `RepeatedPicks`.
- `SuggestionBar.slotCount` owns how many words the bar shows, and `SuggestionBarComposer` uses it.
- Space now considers dictionary words that differ from the typed word in two letters, each a neighbor of the key tapped in its place (`NeighborKeySlips`), so a word typed with the hand a key off can be corrected to the word meant, while a real word typed as meant stays as typed.
- A word the bundled dictionary knows is never replaced by a word that drops one of its tapped letters, at space or once the next word is typed, as on the system keyboard.

### Notes

- `1.0.3` changes no public API, so keyboard hosts need no changes.

## [1.0.2] - 2026-10-27

Taps on the delete key that always delete, so a press near its edge in the middle of a word no longer types the letter beside it.

### Includes

- `ContestedTap.OtherKey` gains a `delete` case, separate from shift, 123, and the globe.
- `ContestedTapPolicy.keepsOtherKey(_:startsWord:landedOnOtherKey:)` now takes the other key and keeps delete for any touch on the key itself, inside a word or at its start.
- A touch in the gap beside delete is still judged against the nearby letters as before.
- Added regression coverage for touches on and beside delete inside a word.

### Notes

- `1.0.2` changes `keepsOtherKey` to take the other key, so keyboard hosts pass the key the tap landed on and report delete as `.delete`.

## [1.0.1] - 2026-10-23

Sentence starts that hold through quotation marks, so the keyboard capitalizes the first word inside or after a quote.

### Includes

- `TypingTextContext.startsSentence(after:)` now reads the text right before the cursor, including the space after a sentence end, and owns the rule that a sentence starts only after that space or a line break.
- An opening quotation mark typed after a sentence end, at the start of the text, or at the start of a line keeps the sentence start, and a closing quotation mark after a period, question mark, or exclamation mark keeps the sentence end before the space that follows it.
- Quotation marks are recognized by their Unicode quotation-mark property, covering straight, smart, and single marks.
- Added regression coverage for sentence starts around the marks the quote keys type.

### Notes

- `1.0.1` moves the full sentence-start decision for automatic capitalization into the package, so keyboard hosts pass the text before the cursor as it is.

## [1.0.0] - 2026-10-13

Initial shared typing prediction and correction system for KeyVox keyboards, matched against the measured behavior of the iOS system keyboard.

### Includes

- Portable English prediction engine built on AOSP LatinIME with KeyVox ranking, bundled language data, and a licensed context model.
- Noisy-channel autocorrection that weighs where each tap landed against how likely each word is in context, with missing-space splits, previous-word revision, and near-miss taps on space, shift, and delete.
- Autocorrection on space, return, and every character that ends a word on the system keyboard.
- Word completions, next-word predictions, sentence openers, and next words that vary across picks made in a row.
- Personal vocabulary from contacts, KeyVox Dictionary words and phrases, and text replacements, spelled with their capitals; common words among them are corrected as ordinary typing.
- Partly typed personal words completed on space only when they fit the words before at least as well as the correction.
- Suggestion taps that place the space around marks as the system keyboard does, and no suggestions right after the marks where it shows none.
- Autocorrections kept when the separator after them is deleted, with the typed words offered in the suggestion bar to put back.
- Typing memory for turned-down corrections, learned words, and learned capitals, with a saved file the host app can reset.
- Smart quotes, press-and-hold characters with system keyboard popup layout, and bundled character lists for typing rules.
- Deterministic regression coverage for corrections, suggestions, personal words, typing memory, held keys, and character lists.

### Notes

- `1.0.0` establishes the UI-independent typing source of truth consumed by the KeyVox keyboard hosts; corrections and predictions are English only.
