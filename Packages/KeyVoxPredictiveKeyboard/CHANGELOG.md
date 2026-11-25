# Changelog

All notable changes to `KeyVoxPredictiveKeyboard` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared typing prediction and correction behavior within the KeyVox monorepo.

---

## [2.1.0] - 2026-11-25

Swipe typing: a finger sliding across the letter keys types the word it traces.

### Includes

- `PredictionComputer.swipeWords(for:previousWords:wordCase:limit:)` decodes a swipe's `SwipeTouchSample` path into ranked words, written as typing writes them: text replacement shortcuts expand, the user's words take their entry's form, learned words and learned capitals apply, and `SwipeWordCase` carries the shift state; `swipeCandidates(for:previousWords:)` returns the ranked spellings with their scores.
- The search covers the typing language's dictionary and swipe vocabulary through a memory-mapped key-path trie (`PredictiveData/en/swipe_lexicon.kvsl`, built by `SwipeLexiconBuilder` from `SwipeVocabulary.lexiconWords(of:)`) and the user's own words beside it: KeyVox Dictionary entries with contact names among them, text replacement shortcuts, and offered learned words.
- The bundled English swipe model (`swipe_encoder.kvsw`, `swipe_decoder.kvsd`, and `swipe.json`) runs from its memory-mapped fp16 weights with Accelerate, and with plain Swift where Accelerate is missing, such as Android; it matches the swipe model tools' reference decoding on swipe.futo.org validation swipes.
- Candidates rank by the model tools' tuned score plus how much likelier the words before make them (`ContextLanguageScorer`); words a swipe cannot tell apart because their key paths are the same, such as "to" and "too", are ordered among themselves: a loop around a key credits each word that has its letter exactly twice there, never one with it three times, and a word adding letters where no loop was read comes after its twins whatever its loops, weighed there only against twins with the same circled letters, whatever the words before (`SwipeKeyLoop`, `loops` in `swipe.json`); without one, no letter is added unless the word without it is a misspelling written `misspellingRatio` times less often (`SwipeTwinFacts`, `swipe.json`), names, contacts, and the user's other words weighed alike; otherwise the words before count more among them (`samePathContextWeight`).
- `SwipeGate` decides which fingers are swiping rather than tapping, so fast taps, rolls, and overlapping two-thumb taps stay taps: a finger meeting the swipe threshold is a swipe once it stays down a moment longer or slows into its lift, and one lifting at speed right after the threshold is a tap when another finger lands soon after; `isTraveling` tells a host when a finger that may still swipe has moved far enough to show a swipe beginning, and `touchStopsSwiping` keeps a finger something else took, such as a held key's popup, from swiping while it stays down, so a finger landing beside it never swipes.
- Swipes decode to the swipe vocabulary (`PredictiveData/en/swipe_vocabulary.txt`, bundled in 2.0.2), such as "haha", "hahaha", "omg", and "lmao"; typing never offers its words.
- `PredictiveTypingSession.swipeEdit(word:textBeforeCursor:selectedText:textAfterCursor:)` inserts a swiped word as a picked word goes in.
- `PredictiveKeyboardError.invalidSwipeModel` reports a damaged or mismatched swipe model file.

### Notes

- `2.1.0` adds public API; typing without swiping is unchanged.

---

## [2.0.2] - 2026-11-25

The English typing language bundles a swipe vocabulary: 22,465 words people write that the English dictionary lacks, so a swipe can decode to them.

### Includes

- `PredictiveData/en/swipe_vocabulary.txt`, one word per line with its probability on the dictionary's 0-255 scale, likeliest first, built by `Tools/KeyVoxLanguageModel` from YouTube-Commons, OASST2, and Tatoeba: words such as "haha", "hahaha", "omg", "lmao", "cuz", and "anyways", British spellings, and names, none of them a dictionary word.

### Notes

- `2.0.2` changes no API or behavior: nothing in the package reads the new file yet, and the dictionary, rankers, and other bundled files are unchanged.

---

## [2.0.1] - 2026-11-24

The bundled English dictionary is the one `Tools/KeyVoxTypingModels` builds, with the same words, word pairs, and three-word sequences at the same probabilities.

### Includes

- `PredictiveData/en/dictionary` is rebuilt from SCOWL and OASST1 at pinned revisions and from Tatoeba's English sentences as of its 2026-07-18 export, checked against their recorded SHA-256; only the order its entries were written in and the write times in its header change.

### Notes

- `2.0.1` changes no API or behavior; the correction and completion rankers, the autocorrect decision model, and the accent overlay the pipeline builds are the same bytes as the bundled ones, so they are unchanged.

---

## [2.0.0] - 2026-11-24

Typing languages: each language the keyboard types in is read from its own folder, and English is the first.

### Includes

- `TypingLanguage.bundled(identifier:)` reads one language from `PredictiveData/<identifier>`: its dictionary, context model, rankers, accent overlay, word lists, held-key characters, and spacing character lists, and from its `language.json` the letter rows, the letters single-letter edits try, the vowels a short typed word needs, the always-capitalized words, and the quotation marks.
- `PredictiveEngine(language:)` replaces `EnglishPredictiveEngine()`, and the native engine takes the language's edit letters and vowels instead of its own English ones, counting a short typed word's length in letters.
- `PredictiveTypingSession(language:)`, `HeldKeyCharacters.bundled(for:)`, and the `CharacterList` lists take the language; `WordCasing` and `SmartQuotes` are the language's (`TypingLanguage.casing`, `TypingLanguage.quotes`), with `WordCasing.writingAlwaysCapitalized` in place of `capitalizingPronoun`.
- The words spelled only with capitals come from the language's `KeyVoxLinguistics` list (`CapitalizedSpellings(languageCode:)`).
- `KeyVoxPredictiveKeyboardResources.configure(bundleURL:)` lets a host outside an app bundle, such as the Android engine, point the package at its unchanged resource bundle, as `KeyVoxCoreResources` and `KeyVoxLinguisticsResources` do.
- The English files move to `PredictiveData/en` under plain names: `dictionary/`, `context_model.bin`, `correction_ranker.kvtr`, `completion_ranker.kvtr`, and `autocorrect_decision.kvtr`.

### Notes

- `2.0.0` changes public API: hosts create the engine and the typing session with a `TypingLanguage`, and call `WordCasing` and `SmartQuotes` through it. English typing is unchanged.

---

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
