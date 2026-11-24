# Changelog

All notable changes to `KeyVoxPredictiveKeyboard` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared typing prediction and correction behavior within the KeyVox monorepo.

---

## [2.1.0] - 2026-11-24

Letter layouts: each of Apple's letter layouts is bundled as data, and each typing language names the one its keyboard shows and the others Apple's keyboard offers.

### Includes

- `PredictiveData/letter_layouts` holds one file per Apple layout name, with the letter rows of Apple's iOS 27.2 iPhone keyboard: QWERTY, QWERTZ, QWERTZ-German, AZERTY, AZERTY-French, QWERTY-Spanish, QWERTY-Accents, QWERTZ-Accents, and Dvorak. Each row lists its character keys, shift and delete keys, and padding, with their widths in letter keys.
- `LetterKeyLayout.bundled(identifier:)` reads one; `LetterKeyLayout` gains its `identifier`, its `rows` (`LetterKeyRow`), and its `width` in letter keys, and its `defaultGeometry` places the layout's letters where Apple's keyboard draws them.
- A language's `language.json` names its `defaultLetterLayout` and Apple's `alternativeLetterLayouts` in Apple's order in place of its own letter rows; `TypingLanguage.letterLayout` is the default layout and `TypingLanguage.alternativeLetterLayouts` names the others. English shows QWERTY and lists AZERTY, QWERTZ, and Dvorak.
- `PredictiveKeyboardError.invalidLetterLayout` reports a layout file that does not decode, names another layout, or has rows of different widths.

### Notes

- `2.1.0` adds public API; English typing is unchanged, its letters sitting where they did.

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
