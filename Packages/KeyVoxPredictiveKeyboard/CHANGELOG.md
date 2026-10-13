# Changelog

All notable changes to `KeyVoxPredictiveKeyboard` will be documented in this file.

The format loosely follows Keep a Changelog, and the package uses semantic versioning for shared typing prediction and correction behavior within the KeyVox monorepo.

---

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
